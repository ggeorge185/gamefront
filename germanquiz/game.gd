extends Control

const ROUND_TIME := 30
const MAX_QUESTIONS := 6  # Changed to 6 questions per round
const MAX_WRONG_ANSWERS := 3  # New: Maximum wrong answers allowed

var full_vocab_data = []
var vocab_data = []
var current_question = {}
var score = 0
var question_index = 0
var wrong_answers = 0  # New: Track wrong answers
var selected_category = ""
var shuffled_questions = []  # New: Store shuffled questions
var quiz_start_time = 0.0

@onready var question_label = $VBox/QuestionLabel
@onready var option_buttons = [$VBox/Option1, $VBox/Option2, $VBox/Option3, $VBox/Option4]
@onready var result_label = $VBox/ResultLabel
@onready var score_label = $VBox/ScoreLabel
@onready var next_button = $VBox/NextButton
@onready var back_button = $VBox/BackButton  # New: Back button
@onready var retry_button = $VBox/RetryButton  # New: Retry button
@onready var wrong_counter_label = $VBox/WrongCounterLabel  # New: Wrong answer counter display
@onready var round_timer = $RoundTimer
@onready var start_screen = $StartScreen
@onready var category_screen = $CategoryScreen
@onready var main_quiz = $VBox
@onready var timer_label = $VBox/TimerLabel
@onready var scoreboard_screen = $ScoreboardScreen
@onready var score_list = $ScoreboardScreen/VBoxContainer/ScoreList

func _on_ScoreboardButton_pressed():
	start_screen.hide()
	scoreboard_screen.show()
	load_scores()

func _on_backbutton_pressed():
	scoreboard_screen.hide()
	start_screen.show()
func _ready():
	start_screen.show()
	category_screen.hide()
	main_quiz.hide()
	load_vocab()
	setup_ui()

func setup_ui():
	# Hide retry button initially
	retry_button.hide()
	# Setup back button (you'll need to add this to your scene)
	if back_button:
		back_button.hide()

func load_vocab():
	var file = FileAccess.open("res://assets/vocab.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_ARRAY:
			full_vocab_data = json
		else:
			question_label.text = "Error loading vocab!"
		file.close()

func _on_StartButton_pressed():
	start_screen.hide()
	category_screen.show()

func _on_TransportButton_pressed():
	start_game_with_category("transport")

func _on_GroceryButton_pressed():
	start_game_with_category("grocery")

func _on_KitchenButton_pressed():
	start_game_with_category("kitchen")

func _on_SchoolButton_pressed():
	start_game_with_category("school")

func _on_FamilyButton_pressed():
	start_game_with_category("family")

func start_game_with_category(category):
	quiz_start_time = Time.get_unix_time_from_system()
	selected_category = category
	vocab_data = full_vocab_data.filter(func(q): return q["category"] == category)
	
	# Shuffle the questions
	shuffled_questions = vocab_data.duplicate()
	shuffled_questions.shuffle()
	
	# Reset game state
	question_index = 0
	score = 0
	wrong_answers = 0
	
	category_screen.hide()
	main_quiz.show()
	back_button.show()  # Show back button during quiz
	retry_button.hide()
	
	update_score_display()
	
	start_question()

func start_question():
	# Check if we've reached max questions or max wrong answers
	if question_index >= MAX_QUESTIONS or question_index >= shuffled_questions.size():
		end_game()
		return
	
	if wrong_answers >= MAX_WRONG_ANSWERS:
		game_over()
		return
	
	current_question = shuffled_questions[question_index]
	question_label.text = "🇬🇧 What is the German word for: " + current_question["english"]
	
	# Shuffle the options for each question
	var options = current_question["choices"].duplicate()
	options.shuffle()
	
	for i in range(4):
		option_buttons[i].text = options[i]
		option_buttons[i].disabled = false
		option_buttons[i].modulate = Color(1, 1, 1)
		option_buttons[i].show()
	
	result_label.text = ""
	next_button.hide()
	timer_label.text = "Time: %d" % ROUND_TIME
	round_timer.stop()
	round_timer.start(ROUND_TIME)

func _process(delta):
	if round_timer.time_left > 0:
		timer_label.text = "Time: %d" % int(round_timer.time_left)

func _on_Option_pressed(index):
	var selected = option_buttons[index].text
	var correct = current_question["german"]
	
	# Disable all buttons and show correct answer
	for i in range(4):
		option_buttons[i].disabled = true
		if option_buttons[i].text == correct:
			option_buttons[i].modulate = Color(0, 1, 0)
		elif option_buttons[i].text == selected:
			option_buttons[i].modulate = Color(1, 0, 0)
	
	if selected == correct:
		result_label.text = "✅ Correct!"
		score += 1
		update_score_display()
		await get_tree().create_timer(1.2).timeout
		question_index += 1
		start_question()
	else:
		wrong_answers += 1
		result_label.text = "❌ Wrong! Answer: " + correct
		update_score_display()
		
		# Check if game should end due to too many wrong answers
		if wrong_answers >= MAX_WRONG_ANSWERS:
			await get_tree().create_timer(1.5).timeout
			game_over()
		else:
			next_button.show()
	
	round_timer.stop()

func _on_NextButton_pressed():
	question_index += 1
	start_question()

func _on_RoundTimer_timeout():
	wrong_answers += 1
	
	for btn in option_buttons:
		btn.disabled = true
		if btn.text == current_question["german"]:
			btn.modulate = Color(0, 1, 0)
	
	result_label.text = "⏰ Time's up! Answer: " + current_question["german"]
	update_score_display()
	
	# Check if game should end due to too many wrong answers
	if wrong_answers >= MAX_WRONG_ANSWERS:
		await get_tree().create_timer(1.5).timeout
		game_over()
	else:
		next_button.show()
func save_score(category: String, score: int, time_taken: int):
	var config = ConfigFile.new()
	var file_path = "user://highscores.cfg"
	var err = config.load(file_path)

	if err != OK:
		print("No highscore file yet, creating one.")

	var best_score = config.get_value(category, "score", 0)
	var best_time = config.get_value(category, "time", 99999)

	if score > best_score or (score == best_score and time_taken < best_time):
		config.set_value(category, "score", score)
		config.set_value(category, "time", time_taken)
		config.save(file_path)

func update_score_display():
	score_label.text = "Score: %d/%d" % [score, MAX_QUESTIONS]

	var wrong_marks := ""
	for i in range(wrong_answers):
		wrong_marks += "❌"
	wrong_counter_label.text = "Wrong: " + wrong_marks

func end_game():
	question_label.text = "🎉 Round Complete!\nFinal Score: %d/%d" % [score, MAX_QUESTIONS]
	for btn in option_buttons:
		btn.hide()
	next_button.hide()
	back_button.hide()
	retry_button.show()
	timer_label.text = ""
	result_label.text = "Great job! Click Retry to play again."
	var time_taken = Time.get_unix_time_from_system() - quiz_start_time
	save_score(selected_category, score, time_taken)

func load_scores():
	var config = ConfigFile.new()
	var file_path = "user://highscores.cfg"
	var err = config.load(file_path)
	if err != OK:
		print("Couldn't load scores.")
		return

	score_list.queue_free_children() # Clear previous scores

	var categories = ["transport", "grocery", "kitchen", "school", "family"]

	for category in categories:
		var best_score = config.get_value(category, "score", 0)
		var best_time = config.get_value(category, "time", 0)

		if best_score == 0:
			continue

		var minutes = int(best_time / 60)
		var seconds = int(best_time % 60)
		var formatted_time = "%02d:%02d" % [minutes, seconds]

		var score_text = "%s: %d/%d in %s" % [
			category.capitalize(),
			best_score,
			MAX_QUESTIONS,
			formatted_time
		]

		var label = Label.new()
		label.text = score_text
		label.add_theme_font_size_override("font_size", 20)
		score_list.add_child(label)

func game_over():
	question_label.text = "💀 Game Over!\nToo many wrong answers!\nFinal Score: %d/%d" % [score, question_index]
	for btn in option_buttons:
		btn.hide()
	next_button.hide()
	back_button.hide()
	retry_button.show()
	timer_label.text = ""
	result_label.text = "Better luck next time! Click Retry to try again."

func _on_BackButton_pressed():
	# Go back to category selection
	main_quiz.hide()
	category_screen.show()
	round_timer.stop()

func _on_RetryButton_pressed():
	# Reset and go back to category selection
	main_quiz.hide()
	category_screen.show()

# Connect Buttons to Handlers
func _on_Option1_pressed(): _on_Option_pressed(0)
func _on_Option2_pressed(): _on_Option_pressed(1)
func _on_Option3_pressed(): _on_Option_pressed(2)
func _on_Option4_pressed(): _on_Option_pressed(3)
