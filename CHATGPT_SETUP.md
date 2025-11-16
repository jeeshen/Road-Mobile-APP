# ChatGPT API Setup

To enable regional traffic summaries, you need to configure the ChatGPT API key.

## Steps:

1. Get your OpenAI API key from https://platform.openai.com/api-keys

2. Update `lib/screens/home_screen.dart`:

```dart
final ChatGPTService? _chatGPTService = ChatGPTService(
  apiKey: 'YOUR_API_KEY_HERE',
);
```

Replace `YOUR_API_KEY_HERE` with your actual OpenAI API key.

## Note:

- The service will automatically fall back to a simple summary if the API call fails
- API calls are made only when entering a new district
- Consider implementing API key storage in environment variables or secure storage for production

