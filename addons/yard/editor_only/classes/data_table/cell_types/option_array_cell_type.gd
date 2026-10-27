# SPDX-FileCopyrightText: 2025-2026, Elliot Fontaine <yard-godot@elliotfontaine.anonaddy.com>
# SPDX-FileCopyrightText: 2026-present, YARD contributors (see AUTHORS.md)
#
# SPDX-License-Identifier: MIT
extends "res://addons/yard/editor_only/classes/data_table/cell_types/popup_menu_cell_type.gd"
## Arrays whose elements are picked from a fixed set of choices: registry string
## IDs (Registry.PROPERTY_HINT_CUSTOM) or int enum values. Elements are drawn as
## colored tags. The popup adds elements: registry arrays take one element per
## pick, as they allow duplicates. Enum arrays get check items like flags, and
## unchecking one also removes it.

const RegistryIO := Namespace.RegistryIO
const RegistryEntryCellType := Namespace.RegistryEntryCellType


static func matches(column: ColumnConfig) -> bool:
	return _is_registry_array(column) or _is_enum_array(column)


static func draw_cell(
	canvas: CanvasItem,
	rect: Rect2,
	value: Variant,
	column: ColumnConfig,
	style: CellStyle,
) -> void:
	var labels := _get_labels(value, column)
	# The element count tells the array apart from a single value, and shows how
	# many elements a narrow column cuts off.
	var prefix := "[%d]" % labels.size()
	if _is_registry_array(column):
		prefix = "%s %s" % [RegistryEntryCellType.RIGHTWARDS_ARROW, prefix]
	var font := resolve_font(column, style.font)
	var prefix_width := font \
			.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, style.font_size) \
			.x
	var x_margin: int = H_ALIGNMENT_MARGINS.get(HORIZONTAL_ALIGNMENT_LEFT)
	draw_text(
		canvas,
		rect,
		prefix,
		font,
		style.font_size,
		HORIZONTAL_ALIGNMENT_LEFT,
		canvas.get_theme_color(&"readonly_color", &"EditorProperty"),
	)
	draw_tags(canvas, rect.grow_side(SIDE_LEFT, -(prefix_width + x_margin)), labels, column, style)


static func get_tooltip(value: Variant, column: ColumnConfig) -> String:
	return "\n".join(_get_labels(value, column))


static func get_sort_key(value: Variant, column: ColumnConfig) -> Variant:
	return " ".join(_get_labels(value, column))


static func get_filter_key(value: Variant, column: ColumnConfig) -> Variant:
	return " ".join(_get_labels(value, column))


## Edits a copy of the array, so elements the popup doesn't list (string IDs no
## longer in the registry, unknown enum values) are kept.
static func create_editor(
	owner: Control,
	rect: Rect2,
	value: Variant,
	column: ColumnConfig,
	on_finished: Callable,
) -> Node:
	var array: Array = (value as Array).duplicate() if value is Array else []
	var element_type := array.get_typed_builtin()
	var is_set := _is_enum_array(column)
	var editor := _create_editor(owner, array)
	var popup_menu := PopupMenu.new()
	popup_menu.hide_on_checkable_item_selection = false
	var choices := _get_choices(column)
	for choice: Variant in choices:
		var element: Variant = choice if element_type == TYPE_NIL else type_convert(choice, element_type)
		if is_set:
			popup_menu.add_check_item(choices[choice])
			popup_menu.set_item_checked(popup_menu.item_count - 1, element in array)
		else:
			popup_menu.add_item(choices[choice])
		popup_menu.set_item_metadata(popup_menu.item_count - 1, element)

	popup_menu.index_pressed.connect(
		func(idx: int) -> void:
			var element: Variant = popup_menu.get_item_metadata(idx)
			if not is_set:
				array.append(element)
				on_finished.call(true)
				return
			popup_menu.toggle_item_checked(idx)
			if popup_menu.is_item_checked(idx):
				array.append(element)
			else:
				while element in array:
					array.erase(element),
	)
	# Like flags, a set commits when its menu closes. Dismissing the other menu cancels.
	_popup_under_cell(popup_menu, editor, rect, on_finished.bind(is_set))
	return editor


static func _is_registry_array(column: ColumnConfig) -> bool:
	return column.type == TYPE_ARRAY and column.property_hint == Registry.PROPERTY_HINT_CUSTOM


static func _is_enum_array(column: ColumnConfig) -> bool:
	return (
		column.type == TYPE_ARRAY
		and column.property_hint == PROPERTY_HINT_TYPE_STRING
		and column.hint_string.begins_with("%d/%d:" % [TYPE_INT, PROPERTY_HINT_ENUM])
	)


static func _get_enum_choices(column: ColumnConfig) -> Dictionary:
	return column.get_cached(
		&"enum_choices",
		parse_enum_hint_string.bind(column.hint_string.split(":", true, 1)[1]),
	) as Dictionary


## Ordered value -> label pairs, in popup order.
static func _get_choices(column: ColumnConfig) -> Dictionary:
	if _is_enum_array(column):
		return _get_enum_choices(column)
	return RegistryEntryCellType.get_choices(RegistryIO.CustomHint.parse(column.hint_string))


static func _get_labels(value: Variant, column: ColumnConfig) -> PackedStringArray:
	var labels := PackedStringArray()
	if value is not Array:
		return labels
	var is_enum := _is_enum_array(column)
	var enum_choices := _get_enum_choices(column) if is_enum else { }
	for element: Variant in value as Array:
		if is_enum:
			labels.append(enum_choices.get(element, "?:%s" % element))
		else:
			labels.append(str(element))
	return labels
