# Peer-review Exam Bot

This bot helps teachers organize peer-review exams for students.

## Installation & Running

### Standard Run
For stable operation, run with your Telegram bot token:

```bash
./ponybot.rb -t "YOUR_TELEGRAM_BOT_TOKEN"
```

### Debug Mode
For debugging with verbose output to both console and log file:

```bash
./ponybot.rb -t "YOUR_TELEGRAM_BOT_TOKEN" -v | tee log
```

## Exam Preparation

### Creating Question Database
Prepare exams offline using the ponymaker script. Example exam format is in the test folder.

```bash
./ponymaker.rb -f test/example_exam.txt -o exam.db
./ponybot.rb -t "YOUR_TELEGRAM_BOT_TOKEN" -v -d exam.db | tee log
```

## Using the Bot

### Registration
1. First registered user becomes admin
2. Students register through the bot

### Teacher Commands
- /addquestion - add exam questions
- /startexam - begin exam (students can submit answers)
- /startreview - start peer-review phase
- /setgrades - finalize grading
- /stopexam - end exam (enables new registrations)
- /exit - shutdown bot gracefully

## Contributing
We welcome pull requests!

Requirements:
- Your MR must pass GitHub Actions pipeline
- Follow existing code style
- Maintain stability
