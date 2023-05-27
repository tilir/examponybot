# Peer-review exam bot

This bot is intended to help teachers with organization of peer-review exams.

## How to run

If you are sure everything is stable, just run providing API token.

```
./ponybot.rb -t "TOKEN"
```

Where TOKEN is your telegram bot token.

Debug run is:

```
./ponybot.rb -t "TOKEN" -v | tee log
```
This will verbosely output everything that happens on console and to log.

## How to use

First you need register yourself: first registered usere considered admin.

Next by series of /addquestion queries create exam.

Now all students shall come and register themselves in your bot.

Teacher starts exam with /startexam. Now students can post answers.

Finally teacher issues /startreview command and peer review starts.

Reviewing ends with /setgrades command from teacher.

After grading is done, issue /stopexam and enable new registrations.

## How to contribute

Without fear. Merge requests are welcome.
