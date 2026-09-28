# Storage and mail

> **Status: planned — Phase 6.** Optional modules, outside the core.

- **Storage:** local disk (development) and S3-compatible services, with
  direct browser uploads using presigned URLs so large files don't pass
  through the API (keeping `max_body_size` small).
- **Mail:** a mailer abstraction with SMTP and API-provider adapters, sent
  through background jobs.

Until then, use gems such as `aws-sdk-s3` or `mail` directly — they work in
any GemStack app.
