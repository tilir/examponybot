#!/usr/bin/env ruby
#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Smoke testing, simple scenarios
#
#------------------------------------------------------------------------------

require_relative './pseudoapi'
require_relative '../lib/handlers'

Logger.set_verbose true
handler = Handler.new("test.db")
api = PseudoApi.new

prepod = PseudoUser.new(167346988, "Tilir")
student1 = PseudoUser.new(2, "student1")
student2 = PseudoUser.new(3, "student2")
student3 = PseudoUser.new(4, "student3")

chat = PseudoChat.new(1)

event = PseudoMessage.new(prepod, chat, "/register")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/addexam")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/stopexam")
handler.process_message(api, event)

q11 = '/addquestion 1 1 наберите три любых слова в столбик'
q12 = '/addquestion 1 2 наберите три любых слова в строку'
q13 = '/addquestion 1 3 ответ -- любая ссылка на https://godbolt.org'
q21 = '/addquestion 2 1 зашлите какую-нибудь математическую формулу'
q22 = '/addquestion 2 2 наберите три слова лесенкой'
q23 = '/addquestion 2 3 наберите все слова лесенкой'
q31 = <<~QST
  /addquestion 3 1 какое
  третье
  слово
  в этом
  вопросе?
QST
q32 = <<~QST
  /addquestion 3 2 какое
  второе
  слово
  в этом
  вопросе?
QST
q33 = <<~QST
  /addquestion 3 3 какое
  первое
  слово
  в этом
  вопросе?
QST

event = PseudoMessage.new(prepod, chat, q11)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q12)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q13)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q21)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q22)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q23)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q31)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q32)
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, q33)
handler.process_message(api, event)

# expect not enough rights
event = PseudoMessage.new(student1, chat, "/questions")
handler.process_message(api, event)

# expect ok
event = PseudoMessage.new(prepod, chat, "/questions")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/register")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/register")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/register")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/users")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/startexam")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/answer 1 singleline from student1")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/answer 1 singleline from student2")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/answer 1 singleline from student3")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_answer 1")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_answer 2")
handler.process_message(api, event)

a21 = <<~ANS
  /answer 2
  УХ
  как я
  отвечаю
ANS
a22 = <<~ANS
  /answer 2
  ЭХ
  как я
  отвечаю
ANS
a23 = <<~ANS
  /answer 2
  ЫХ
  как я
  отвечаю
ANS

event = PseudoMessage.new(student1, chat, a21)
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, a22)
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, a23)
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_answer 2")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_answer")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_question 1")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/lookup_question")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/answer 3 singleline from student1")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/answer 3 singleline from student2")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/answer 3 singleline from student3")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/startreview")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 10 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 11 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 12 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 12 4 like it better")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 13 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 14 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 15 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 112 2 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 12 -1 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 12 100 don't like it")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/review 9.5")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/lookup_review 10")
handler.process_message(api, event)

event = PseudoMessage.new(student1, chat, "/lookup_review 112")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 1 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 2 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 3 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 16 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 17 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/review 18 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/review 4 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/review 5 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/review 6 10 like it")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/setgrades")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/stopexam")
handler.process_message(api, event)
