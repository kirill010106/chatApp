package ws

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Envelope types for WebSocket messages
const (
	TypeMessage     = "message"
	TypeTyping      = "typing"
	TypePresence    = "presence"
	TypeAck         = "ack"
	TypeReadReceipt = "read_receipt"
	TypeError       = "error"
)

// IncomingMessage is sent from client to server.
type IncomingMessage struct {
	Type           string `json:"type"`
	ConversationID string `json:"conversation_id"`
	Content        string `json:"content"`
	ContentType    string `json:"content_type,omitempty"`
	ClientMsgID    string `json:"client_msg_id,omitempty"`
}

// OutgoingMessage is sent from server to client.
type OutgoingMessage struct {
	Type           string    `json:"type"`
	ID             string    `json:"id,omitempty"`
	ConversationID string    `json:"conversation_id,omitempty"`
	SenderID       string    `json:"sender_id,omitempty"`
	Content        string    `json:"content,omitempty"`
	ContentType    string    `json:"content_type,omitempty"`
	CreatedAt      time.Time `json:"created_at,omitempty"`
	ClientMsgID    string    `json:"client_msg_id,omitempty"`
	Error          string    `json:"error,omitempty"`
}

// NewMessageOut creates an outgoing message for a sent message.
func NewMessageOut(id, conversationID, senderID uuid.UUID, content, contentType, clientMsgID string, createdAt time.Time) []byte {
	msg := OutgoingMessage{
		Type:           TypeMessage,
		ID:             id.String(),
		ConversationID: conversationID.String(),
		SenderID:       senderID.String(),
		Content:        content,
		ContentType:    contentType,
		CreatedAt:      createdAt,
		ClientMsgID:    clientMsgID,
	}
	data, _ := json.Marshal(msg)
	return data
}

// NewErrorOut creates an outgoing error message.
func NewErrorOut(errMsg string) []byte {
	msg := OutgoingMessage{
		Type:  TypeError,
		Error: errMsg,
	}
	data, _ := json.Marshal(msg)
	return data
}

// NewReadReceiptOut creates an outgoing read receipt.
func NewReadReceiptOut(conversationID, userID uuid.UUID) []byte {
	msg := OutgoingMessage{
		Type:           TypeReadReceipt,
		ConversationID: conversationID.String(),
		SenderID:       userID.String(),
	}
	data, _ := json.Marshal(msg)
	return data
}
