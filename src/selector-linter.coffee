_ = require "underscore-plus"
{selectorHasClass, eachSelector, selectorHasPsuedoClass} = require "./helpers"

CLASS_TO_TAG =
  "workspace": "atom-workspace"
  "pane": "atom-pane"
  "pane-container": "atom-pane-container"
  "text-editor": "atom-text-editor"
  "tool-panel": "atom-panel"

CLASS_TO_SELECTOR =
  "overlay": "atom-panel[location=\"modal\"]"
  "panel-top": "atom-panel[location=\"top\"]"
  "panel-left": "atom-panel[location=\"left\"]"
  "panel-right": "atom-panel[location=\"right\"]"
  "panel-bottom": "atom-panel[location=\"bottom\"]"

module.exports =
class SelectorLinter
  constructor: ({maxPerFile})->
    @maxPerFile = maxPerFile ? 50
    @deprecations = {}

  checkKeymap: (keymap, metadata) ->
    for selector of keymap
      @check(selector, metadata)

  checkUIStylesheet: (css, metadata) ->
    shadowSelectorUsed = editorDescendentUsed = false
    eachSelector css, (selector) =>
      @check(selector, metadata)
      editorDescendentUsed ||= /(\.text-editor|\.editor|atom-text-editor).*\w/.test(selector)
      shadowSelectorUsed ||= selectorHasPsuedoClass(selector, ":shadow")
    if editorDescendentUsed and not shadowSelectorUsed
      @addDeprecation(metadata, "Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension")

  checkSyntaxStylesheet: (css, metadata) ->
    hostSelectorUsed = editorSelectorUsed = false
    eachSelector css, (selector) =>
      @check(selector, metadata)
      editorSelectorUsed ||= selectorHasClass(selector, "editor")
      hostSelectorUsed ||= selectorHasPsuedoClass(selector, "host")
    if editorSelectorUsed and not hostSelectorUsed
      @addDeprecation(metadata, "Target the `:host` psuedo-selector in addition to the `editor` class for forward-compatibility")

  checkMenu: (menu, metadata) ->
    for selector of menu['context-menu']
      @check(selector, metadata)

  check: (selector, metadata) ->
    for klass, tag of CLASS_TO_TAG
      if selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the `#{tag}` tag instead of the `#{klass}` class.")

    for klass, replacement of CLASS_TO_SELECTOR
      if selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the selector `#{replacement}` instead of the `#{klass}` class.")

    if selectorHasClass(selector, "editor") and selectorHasClass(selector, "mini")
      @addDeprecation(metadata, "Use the selector `.editor[mini]` to select mini-editors.")

    if selectorHasClass(selector, "bracket-matcher") and not selectorHasClass(selector, "region")
      @addDeprecation(metadata, "Use `.bracket-matcher .region` to select highlighted brackets.")

  clearDeprecations: ->
    @deprecations = {}

  getDeprecations: ->
    @deprecations

  # Private

  addDeprecation: (metadata, message) ->
    {packageName, sourcePath} = metadata
    @deprecations[packageName] ?= {}
    fileDeprecations = @deprecations[packageName][sourcePath] ?= []
    deprecation = _.extend(
      _.omit(metadata, "packageName", "sourcePath"),
      {message}
    )

    return if fileDeprecations.length >= @maxPerFile
    return if _.any fileDeprecations, (existing) -> _.isEqual(existing, deprecation)
    fileDeprecations.push(deprecation)
