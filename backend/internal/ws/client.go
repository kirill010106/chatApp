package ws

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"nhooyr.io/websocket"
	"nhooyr.io/websocket/wsjson"

	"github.com/konst/chatapp-backend/internal/service"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 30 * time.Second
	maxMessageSize = 4096
	sendBufSize    = 256
)

// Client represents a single WebSocket connection.
type Client struct {
	hub         *Hub
	UserID      uuid.UUID
	senderName  string
	conn        *websocket.Conn
	send        chan []byte
	msgSvc      *service.MessageService
	chatSvc     *service.ChatService
	pushSvc     *service.PushService
}

func NewClient(hub *Hub, userID uuid.UUID, senderName string, conn *websocket.Conn, msgSvc *service.MessageService, chatSvc *service.ChatService, pushSvc *service.PushService) *Client {
	return &Client{
		hub:        hub,
		UserID:     userID,
		senderName: senderName,
		conn:       conn,
		send:       make(chan []byte, sendBufSize),
		msgSvc:     msgSvc,
		chatSvc:    chatSvc,
		pushSvc:    pushSvc,
	}
}

// ReadPump reads messages from the WebSocket connection.
func (c *Client) ReadPump() {
	defer func() {
		c.hub.Unregister(c)
		c.conn.Close(websocket.StatusNormalClosure, "")
	}()

	c.conn.SetReadLimit(maxMessageSize)

	for {
		_, data, err := c.conn.Read(context.Background())
		if err != nil {
			if websocket.CloseStatus(err) != websocket.StatusNormalClosure {
				log.Error().Err(err).Str("user_id", c.UserID.String()).Msg("ws: read error")
			}
			return
		}

		var incoming IncomingMessage
		if err := json.Unmarshal(data, &incoming); err != nil {
			c.sendError("invalid message format")
			continue
		}

		switch incoming.Type {
		case TypeMessage:
			c.handleMessage(incoming)
		case TypeReadReceipt:
			c.handleReadReceipt(incoming)
		default:
			c.sendError("unknown message type")
		}
	}
}

// WritePump writes messages to the WebSocket connection.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close(websocket.StatusNormalClosure, "")
	}()

	for {
		select {
		case message, ok := <-c.send:
			if !ok {
				// Hub closed the channel
				return
			}
			ctx, cancel := context.WithTimeout(context.Background(), writeWait)
			err := c.conn.Write(ctx, websocket.MessageText, message)
			cancel()
			if err != nil {
				log.Error().Err(err).Str("user_id", c.UserID.String()).Msg("ws: write error")
				return
			}

		case <-ticker.C:
			ctx, cancel := context.WithTimeout(context.Background(), writeWait)
			err := c.conn.Ping(ctx)
			cancel()
			if err != nil {
				log.Error().Err(err).Str("user_id", c.UserID.String()).Msg("ws: ping error")
				return
			}
		}
	}
}

func (c *Client) handleMessage(incoming IncomingMessage) {
	convID, err := uuid.Parse(incoming.ConversationID)
	if err != nil {
		c.sendError("invalid conversation_id")
		return
	}

	if incoming.Content == "" {
		c.sendError("content is empty")
		return
	}

	contentType := incoming.ContentType
	if contentType == "" {
		contentType = "text"
	}

	// Persist the message
	msg, err := c.msgSvc.SendMessage(c.UserID, convID, incoming.Content, contentType)
	if err != nil {
		log.Error().Err(err).Msg("ws: failed to persist message")
		c.sendError("failed to send message")
		return
	}

	// Build outgoing message
	outData := NewMessageOut(msg.ID, msg.ConversationID, msg.SenderID, msg.Content, msg.ContentType, incoming.ClientMsgID, msg.CreatedAt)

	// Get participants and broadcast
	participants, err := c.chatSvc.GetParticipants(convID)
	if err != nil {
		log.Error().Err(err).Msg("ws: failed to get participants")
		return
	}

	c.hub.SendToUsers(participants, outData)

	// Send push notifications to offline participants
	if c.pushSvc != nil {
		for _, uid := range participants {
			if uid == c.UserID {
				continue // don't notify sender
			}
			if !c.hub.IsOnline(uid) {
				title := c.senderName
				if title == "" {
					title = "New message"
				}
				c.pushSvc.SendNotification(uid, service.PushPayload{
					Title:          title,
					Body:           incoming.Content,
					ConversationID: convID.String(),
					SenderID:       c.UserID.String(),
				})
			}
		}
	}
}

func (c *Client) handleReadReceipt(incoming IncomingMessage) {
	convID, err := uuid.Parse(incoming.ConversationID)
	if err != nil {
		c.sendError("invalid conversation_id")
		return
	}

	if err := c.chatSvc.MarkRead(convID, c.UserID); err != nil {
		log.Error().Err(err).Msg("ws: failed to mark read")
		c.sendError("failed to mark read")
		return
	}

	// Notify other participants that this user has read the conversation
	participants, err := c.chatSvc.GetParticipants(convID)
	if err != nil {
		log.Error().Err(err).Msg("ws: failed to get participants")
		return
	}

	outData := NewReadReceiptOut(convID, c.UserID)
	c.hub.SendToUsers(participants, outData)
}

func (c *Client) sendError(errMsg string) {
	ctx, cancel := context.WithTimeout(context.Background(), writeWait)
	defer cancel()
	_ = wsjson.Write(ctx, c.conn, OutgoingMessage{Type: TypeError, Error: errMsg})
}
