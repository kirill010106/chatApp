package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func main() {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion("us-east-1"),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			"PLACEHOLDER_ACCESS_KEY",
			"PLACEHOLDER_SECRET_KEY",
			"",
		)),
	)
	if err != nil {
		fmt.Println("config error:", err)
		return
	}
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String("https://s3.example.com")
		o.UsePathStyle = true
	})

	bucket := "chatapp-media"

	// Set bucket ACL to public-read so files can be served directly
	_, err = client.PutBucketAcl(context.TODO(), &s3.PutBucketAclInput{
		Bucket: aws.String(bucket),
		ACL:    types.BucketCannedACLPublicRead,
	})
	if err != nil {
		fmt.Println("PutBucketAcl error:", err)
	} else {
		fmt.Println("Bucket ACL set to public-read")
	}

	// Verify
	out, err := client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
	if err != nil {
		fmt.Println("ListBuckets error:", err)
	} else {
		fmt.Println("Buckets:")
		for _, b := range out.Buckets {
			fmt.Println("  -", *b.Name)
		}
	}
}
