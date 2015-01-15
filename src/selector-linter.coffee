_ = require "underscore-plus"
path = require "path"
{selectorHasClass, eachSelector, selectorHasPsuedoClass} = require "./helpers"

CLASS_TO_TAG =
  "workspace": "atom-workspace"
  "pane": "atom-pane"
  "panes": "atom-pane-container"
  "editor": "atom-text-editor"
  "editor-colors": "atom-text-editor"

CLASS_TO_SELECTOR =
  "pane-row": "atom-pane-axis.horizontal"
  "pane-column": "atom-pane-axis.vertical"

CLASS_TO_SELECTOR_WITH_BACKWARD_COMPATIBILITY =
  "overlay": "atom-panel.modal"
  "panel-top": "atom-panel.top"
  "panel-left": "atom-panel.left"
  "panel-right": "atom-panel.right"
  "panel-bottom": "atom-panel.bottom"
  "tool-panel": "atom-panel"

module.exports =
class SelectorLinter
  constructor: ->
    @deprecations = {}

  checkPackage: (pkg) ->
    for [sourcePath, menu] in pkg.menus
      @checkMenu(menu, @packageMetadata(pkg, sourcePath))
    for [sourcePath, keymap] in pkg.keymaps
      @checkKeymap(keymap, @packageMetadata(pkg, sourcePath))
    for [sourcePath, stylesheet] in pkg.stylesheets
      if pkg.metadata["theme"] is "syntax" or /atom-text-editor\.(less|css)/.test(sourcePath)
        @checkSyntaxStylesheet(stylesheet, @packageMetadata(pkg, sourcePath))
      else
        @checkUIStylesheet(stylesheet, @packageMetadata(pkg, sourcePath))

  checkKeymap: (keymap, metadata) ->
    for selector of keymap
      @check(selector, metadata)

  checkUIStylesheet: (css, metadata) ->
    shadowSelectorUsed = editorDescendentUsed = false

    selectorsUsed = {}

    eachSelector css, (selector) =>
      @check(selector, metadata, true)

      for klass, replacementSelector of CLASS_TO_SELECTOR_WITH_BACKWARD_COMPATIBILITY
        selectorsUsed[klass] ||= selectorHasClass(selector, klass)
        selectorsUsed[replacementSelector] ||= selector.indexOf(replacementSelector) >= 0

      editorDescendentUsed ||= /(\.text-editor|\.editor|atom-text-editor).*[ >].*\w/.test(selector)
      shadowSelectorUsed ||= selectorHasPsuedoClass(selector, ":shadow")

    for klass, replacementSelector of CLASS_TO_SELECTOR_WITH_BACKWARD_COMPATIBILITY
      if selectorsUsed[klass] and not selectorsUsed[replacementSelector]
        @addDeprecation(metadata, "Use the selector `#{replacementSelector}` instead of the `#{klass}` class.")

    if editorDescendentUsed and not shadowSelectorUsed
      @addDeprecation(metadata, """
        Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension.
        If you want to target overlay elements, target them directly or as descendants of `atom-overlay` elements.
      """)

  checkSyntaxStylesheet: (css, metadata) ->
    hostSelectorUsed = editorClassUsed = editorColorsClassUsed = false
    eachSelector css, (selector) =>
      @check(selector, metadata)
      editorClassUsed ||= selectorHasClass(selector, "editor")
      editorColorsClassUsed ||= selectorHasClass(selector, "editor-colors")
      hostSelectorUsed ||= selectorHasPsuedoClass(selector, "host")
    unless hostSelectorUsed
      if editorClassUsed
        @addDeprecation(metadata, "Target the selector `:host, atom-text-editor` instead of `.editor` for shadow DOM support.")
      if editorColorsClassUsed
        @addDeprecation(metadata, "Target the selector `:host, atom-text-editor` instead of `.editor-colors` for shadow DOM support.")

  checkMenu: (menu, metadata) ->
    for selector of menu['context-menu']
      @check(selector, metadata)

  check: (selector, metadata, skipBackwardCompatible=false) ->
    for klass, tag of CLASS_TO_TAG
      if selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the `#{tag}` tag instead of the `#{klass}` class.")

    for klass, replacement of CLASS_TO_SELECTOR
      if selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the selector `#{replacement}` instead of the `#{klass}` class.")

    unless skipBackwardCompatible
      for klass, replacement of CLASS_TO_SELECTOR_WITH_BACKWARD_COMPATIBILITY
        if selectorHasClass(selector, klass)
          @addDeprecation(metadata, "Use the selector `#{replacement}` instead of the `#{klass}` class.")

    if selectorHasClass(selector, "editor") and selectorHasClass(selector, "mini")
      @addDeprecation(metadata, "Use the selector `atom-text-editor[mini]` to select mini-editors.")

    if selectorHasClass(selector, "bracket-matcher") and not selectorHasClass(selector, "region")
      @addDeprecation(metadata, "Use `.bracket-matcher .region` to select highlighted brackets.")

  clearDeprecations: ->
    @deprecations = {}

  getDeprecations: ->
    @deprecations

  # Private

  packageMetadata: (pkg, sourcePath) ->
    {
      packageName: pkg.name,
      packagePath: pkg.path,
      sourcePath: path.relative(pkg.path, sourcePath)
    }

  addDeprecation: (metadata, message) ->
    {packageName, sourcePath} = metadata
    @deprecations[packageName] ?= {}
    fileDeprecations = @deprecations[packageName][sourcePath] ?= []
    deprecation = _.extend(
      _.omit(metadata, "packageName", "sourcePath"),
      {message}
    )

    unless _.any(fileDeprecations, (existing) -> _.isEqual(existing, deprecation))
      fileDeprecations.push(deprecation)
