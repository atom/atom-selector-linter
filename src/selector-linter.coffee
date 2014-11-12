_ = require "underscore-plus"

DEPRECATED_CLASSES =
  "workspace": "atom-workspace"
  "pane": "atom-pane"
  "pane-container": "atom-pane-container"
  "text-editor": "atom-text-editor"

module.exports =
class SelectorLinter
  constructor: ->
    @deprecations = {}

  check: (selector, metadata) ->
    for klass, tag of DEPRECATED_CLASSES
      if @selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the `#{tag}` tag instead of the `#{klass}` class.")

    if @selectorHasClass(selector, "bracket-matcher") and not /bracket-matcher.*region/.test(selector)
      @addDeprecation(metadata, "Use `.bracket-matcher .region` to select highlighted brackets.")

  getDeprecations: ->
    @deprecations

  # Private

  addDeprecation: ({packageName, sourcePath, lineNumber}, message) ->
    @deprecations[packageName] ?= []
    @deprecations[packageName].push({sourcePath, lineNumber, message})

  selectorHasClass: (selector, klass) ->
    new RegExp("\\.#{klass}([ >\.:]|$)").test(selector)
