<?php

require __DIR__.'/vendor/autoload.php'; // Siguraduhing tumatakbo ito sa Laravel root mo

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

// Gumamit ng tamang path base sa previous message mo
$factory = (new Factory)
    ->withServiceAccount(__DIR__.'/storage/app/docusys-mobile-firebase-adminsdk-fbsvc-c51df7795f.json');

$messaging = $factory->createMessaging();

// I-paste dito yung token from your app log
$deviceToken = 'czRxAGowT_Ka2hqBdYr-_n:APA91bGqzBvzYY1gnw6aBA26xeg1u3hEWfxFHXa-OTZ6GLahVYyidENQfoTxfo6iRpLpywksvFvsO9MgLQG9Eiu7s-7YqVjvaQqi9tX25vW3T6h2AOJj6P8';

$notification = Notification::create('Isang Test Notification!', 'Galing direct sa PHP script 🚀');

$message = CloudMessage::withTarget('token', $deviceToken)
    ->withNotification($notification);

try {
    $messaging->send($message);
    echo "Message successfully sent!\n";
} catch (\Exception $e) {
    echo "Error sending message: " . $e->getMessage() . "\n";
}
