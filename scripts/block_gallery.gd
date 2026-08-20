extends Node2D

const SHAPE_FILES := [
	"square",
	"half_square",
	"rectangle",
	"large",
	"platform",
	"rod",
	"slope",
]

const SHAPE_NAMES := [
	"정사각형 1×1",
	"반사각형 1×0.5",
	"직사각형 2×1",
	"대형 2×2",
	"발판 0.5×3",
	"막대 0.25×3",
	"경사 3×2",
]

const MATERIAL_FILES := ["wood", "stone", "metal"]
const MATERIAL_NAMES := ["나무", "석재", "금속"]
const ROW_COLORS := [Color("#e0e0e0"), Color("#a0a0a0"), Color("#606060")]


func _ready() -> void:
	_create_title()
	_create_blocks()


func _create_title() -> void:
	var title := Label.new()
	title.text = "블록 카탈로그 — 7가지 모양 × 3가지 재질"
	title.position = Vector2(30, 18)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)

	var note := Label.new()
	note.text = "표시 질량 = 블록 면적 × 재질 밀도 (나무 1 / 석재 2.5 / 금속 5)"
	note.position = Vector2(31, 54)
	note.modulate = Color("#b8b8b8")
	note.add_theme_font_size_override("font_size", 16)
	add_child(note)


func _create_blocks() -> void:
	for material_index in MATERIAL_FILES.size():
		var row_y := 170.0 + material_index * 205.0
		var row_label := Label.new()
		row_label.text = MATERIAL_NAMES[material_index]
		row_label.position = Vector2(24, row_y - 18)
		row_label.modulate = ROW_COLORS[material_index]
		row_label.add_theme_font_size_override("font_size", 22)
		add_child(row_label)

		for shape_index in SHAPE_FILES.size():
			var scene_path := "res://blocks/%s_%s.tscn" % [
				MATERIAL_FILES[material_index], SHAPE_FILES[shape_index]
			]
			var packed_scene := load(scene_path) as PackedScene
			var block := packed_scene.instantiate() as PhysicsBlock
			block.position = Vector2(155.0 + shape_index * 175.0, row_y + 36.0)
			block.scale = Vector2.ONE * 0.55
			block.freeze = true
			add_child(block)

			var shape_label := Label.new()
			shape_label.text = "%s\n질량 %.2f" % [SHAPE_NAMES[shape_index], block.mass]
			shape_label.position = Vector2(
				95.0 + shape_index * 175.0,
				row_y + 105.0
			)
			shape_label.size = Vector2(130, 50)
			shape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			shape_label.add_theme_font_size_override("font_size", 13)
			add_child(shape_label)
