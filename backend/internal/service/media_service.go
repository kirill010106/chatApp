package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"path"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

type MediaService struct {
	client   *s3.Client
	bucket   string
	endpoint string
}

// NewMediaService creates a new S3-backed media service.
func NewMediaService(endpoint, accessKey, secretKey, bucket, region string) (*MediaService, error) {
	cfg, err := awsconfig.LoadDefaultConfig(context.TODO(),
		awsconfig.WithRegion(region),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			accessKey, secretKey, "",
		)),
	)
	if err != nil {
		return nil, fmt.Errorf("media service: load aws config: %w", err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = true
		// Disable default CRC32 checksums — many S3-compatible providers
		// (MinIO, Ceph, itecocloud) reject them with InvalidArgument.
		o.RequestChecksumCalculation = aws.RequestChecksumCalculationWhenRequired
		o.ResponseChecksumValidation = aws.ResponseChecksumValidationWhenRequired
	})

	// Try to set a public-read bucket policy so uploaded objects are accessible.
	policy := fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::%s/*"}]}`, bucket)
	_, _ = client.PutBucketPolicy(context.TODO(), &s3.PutBucketPolicyInput{
		Bucket: aws.String(bucket),
		Policy: aws.String(policy),
	})

	// Set CORS on the bucket so browsers can load images/media directly.
	_, _ = client.PutBucketCors(context.TODO(), &s3.PutBucketCorsInput{
		Bucket: aws.String(bucket),
		CORSConfiguration: &s3types.CORSConfiguration{
			CORSRules: []s3types.CORSRule{
				{
					AllowedOrigins: []string{"*"},
					AllowedMethods: []string{"GET", "HEAD"},
					AllowedHeaders: []string{"*"},
					MaxAgeSeconds:  aws.Int32(3600),
				},
			},
		},
	})

	return &MediaService{
		client:   client,
		bucket:   bucket,
		endpoint: strings.TrimRight(endpoint, "/"),
	}, nil
}

// UploadResult holds the result of an upload.
type UploadResult struct {
	URL         string `json:"url"`
	Key         string `json:"key"`
	ContentType string `json:"content_type"`
	Size        int64  `json:"size"`
}

// Upload stores a file in S3 and returns its public URL.
func (s *MediaService) Upload(ctx context.Context, userID uuid.UUID, filename string, contentType string, size int64, body io.Reader) (*UploadResult, error) {
	ext := path.Ext(filename)
	key := fmt.Sprintf("uploads/%s/%d%s", userID.String(), time.Now().UnixNano(), ext)

	// Read the full body into memory so we have an accurate content length
	// and a seekable reader (required by some S3-compatible providers).
	data, err := io.ReadAll(body)
	if err != nil {
		return nil, fmt.Errorf("media service: read body: %w", err)
	}

	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucket),
		Key:           aws.String(key),
		Body:          bytes.NewReader(data),
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(int64(len(data))),
	})
	if err != nil {
		log.Error().Err(err).Str("key", key).Msg("s3: failed to upload")
		return nil, fmt.Errorf("media service: upload: %w", err)
	}

	url := fmt.Sprintf("/api/v1/media/%s", key)

	return &UploadResult{
		URL:         url,
		Key:         key,
		ContentType: contentType,
		Size:        int64(len(data)),
	}, nil
}

// Delete removes a file from S3.
func (s *MediaService) Delete(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	return err
}

// GetObject fetches a file from S3 and returns its body, content type and size.
func (s *MediaService) GetObject(ctx context.Context, key string) (io.ReadCloser, string, int64, error) {
	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, "", 0, err
	}
	ct := ""
	if out.ContentType != nil {
		ct = *out.ContentType
	}
	var sz int64
	if out.ContentLength != nil {
		sz = *out.ContentLength
	}
	return out.Body, ct, sz, nil
}
