_ = require "underscore-plus"

DEPRECATED_CLASSES =
  "workspace": "atom-workspace"
  "pane": "atom-pane"
  "pane-container": "atom-pane-container"
  "text-editor": "atom-text-editor"

module.exports =
class SelectorLinter
  constructor: ({maxPerFile})->
    @maxPerFile = maxPerFile ? 50
    @deprecations = {}

  checkKeymap: (keymap, metadata) ->
    for selector of keymap
      @check(selector, metadata)

  checkStylesheet: (css, metadata) ->
    for line in css.split("\n")
      unless line.indexOf(";") > 0
        @check(line, metadata)

  checkMenu: (menu, metadata) ->
    for selector of menu['context-menu']
      @check(selector, metadata)

  check: (selector, metadata) ->
    for klass, tag of DEPRECATED_CLASSES
      if @selectorHasClass(selector, klass)
        @addDeprecation(metadata, "Use the `#{tag}` tag instead of the `#{klass}` class.")

    if @selectorHasClass(selector, "bracket-matcher") and not /bracket-matcher.*region/.test(selector)
      @addDeprecation(metadata, "Use `.bracket-matcher .region` to select highlighted brackets.")

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

  selectorHasClass: (selector, klass) ->
    new RegExp("\\.#{klass}([ >\.:]|$)").test(selector)
