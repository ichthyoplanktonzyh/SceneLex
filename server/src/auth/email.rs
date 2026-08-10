/// Email delivery abstraction. Local dev logs to stdout.
#[async_trait::async_trait]
pub trait EmailSender: Send + Sync {
    async fn send_otp(&self, to: &str, code: &str);
}

/// Development sender: prints the code to the server log.
pub struct LogEmailSender;

#[async_trait::async_trait]
impl EmailSender for LogEmailSender {
    async fn send_otp(&self, to: &str, code: &str) {
        tracing::info!("[DEV EMAIL] to={to} code={code}");
    }
}
