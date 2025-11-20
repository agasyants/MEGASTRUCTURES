extends CanvasLayer
# Make it Autoload

var active := true
var active_labels: Array[String] = []
var labels: Array[Label] = []

var margin_x := 100.0
var margin_y := 50.0

func _ready() -> void:
	create_labels(3)

func activate():
	active = true
	visible = true

func deactivate():
	active = false
	visible = false

func create_labels(n:int):
	for i in range(n):
		var label = Label.new()
		label.position.x = margin_x
		label.position.y = margin_y + i * 100
		label.text = "hello!"
		label.add_theme_font_size_override("font_size", 60)
		labels.append(label)
		self.add_child(label)

func hide_labels(n:int):
	for l in labels.slice(-n):
		l.hide()

func _process(_delta: float) -> void:
	var res = len(active_labels) - len(labels)
	if res > 0:
		create_labels(res)
	elif res < 0:
		hide_labels(-res)
	
	for i in range(len(active_labels)):
		labels[i].show()
		labels[i].text = str(active_labels[i])
	
	active_labels = []

func Log(value:Variant, prefix:String = ""):
	if active:
		active_labels.append(prefix + str(value))
