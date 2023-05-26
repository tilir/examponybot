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

handler = Handler.new("test.db", true)
api = PseudoApi.new

prepod = PseudoUser.new(1, "prepod")
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

event = PseudoMessage.new(student1, chat, "/answer 3 singleline from student1")
handler.process_message(api, event)

event = PseudoMessage.new(student2, chat, "/answer 3 singleline from student2")
handler.process_message(api, event)

event = PseudoMessage.new(student3, chat, "/answer 3 singleline from student3")
handler.process_message(api, event)

event = PseudoMessage.new(prepod, chat, "/startreview")
handler.process_message(api, event)
