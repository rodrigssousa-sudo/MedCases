# Restricted push diagnostics update

Apply each patch only to its matching production source archive and verify the before/after SHA256 in manifest.json. These patches change only native_notifications.js; all other source bytes, trigger/configuration and secrets remain those of that function's recorded production revision.

Targets: deliverNativeNotification/us-east1 (delivernativenotification-00001-xot) and registerNotificationDevice/us-central1 (registernotificationdevice-00002-red).

Production source archives:
- gs://gcf-v2-sources-1076800980330-us-east1/deliverNativeNotification/function-source.zip#1790643534518021
- gs://gcf-v2-sources-1076800980330-us-central1/registerNotificationDevice/function-source.zip#1790646405977306

Run regression.test.js with PUSH_SOURCE set to the extracted patched source directory. The delivery baseline predates late-registration recovery, which is tested on the registration candidate only. Do not copy the whole local application checkout into these deployment sources.

Only SEND_ACCEPTED, providerMessageId, and classified reasonCode are added to existing delivery receipts. No token, clinical content or raw provider exception is logged. Error classes not explicitly exposed by FCM remain UNKNOWN_PROVIDER_FAILURE; APNs topic/environment causes must not be inferred from generic errors.
