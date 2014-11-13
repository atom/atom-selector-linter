SelectorLinter = require "../src/selector-linter"
_ = require 'underscore-plus'

describe "SelectorLinter", ->
  linter = null

  beforeEach ->
    linter = new SelectorLinter(maxPerFile: 10)

  describe "::checkKeymap(keymap, metadata)", ->
    it "records deprecations in the keymap", ->
      linter.checkKeymap({
        ".workspace":
          "cmd-t": "the-namespace:the-command"
      }, {
        packageName: "the-package"
        sourcePath: "keymaps/the-keymap.cson"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "keymaps/the-keymap.cson": [{
            message: "Use the `atom-workspace` tag instead of the `workspace` class."
          }]

  describe "::checkMenu(menu, metadata)", ->
    it "records deprecations in the menu's context menu", ->
      linter.checkMenu({
        "context-menu":
          ".text-editor":
            "The Command": "the-namespace:the-command"
      }, {
        packageName: "the-package"
        sourcePath: "keymaps/the-keymap.cson"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "keymaps/the-keymap.cson": [{
            message: "Use the `atom-text-editor` tag instead of the `text-editor` class."
          }]

  describe "::checkUIStylesheet(css, metadata)", ->
    expectDeprecation = (css, message) ->
      linter.clearDeprecations()
      linter.checkUIStylesheet(css, {
        packageName: "the-package",
        sourcePath: "index.less"
      })
      expect(linter.getDeprecations()["the-package"]["index.less"]).toContain({message})

    it "records deprecations in the CSS", ->
      expectDeprecation(
        ".workspace { color: blue; }"
        "Use the `atom-workspace` tag instead of the `workspace` class."
      )

    it "suggests using the shadow DOM psuedo selectors or the context stylesheet", ->
      expectDeprecation(
        ".editor .cursor { background-color: #aaa; }",
        "Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension"
      )
      expectDeprecation(
        ".text-editor .cursor { background-color: #aaa; }",
        "Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension"
      )
      expectDeprecation(
        "atom-text-editor .cursor { background-color: #aaa; }",
        "Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension"
      )

    it "doesn't suggest the ::shadow psuedo-selector if it is in use", ->
      linter.checkUIStylesheet("""
        atom-text-editor span, atom-text-editor::shadow span {
          color: black;
        }
      """, {
        packageName: "the-package",
        sourcePath: "index.less"
      })
      expect(linter.getDeprecations()).toEqual({})

  describe "::checkSyntaxStylesheet(css, metadata)", ->
    expectDeprecation = (css, message) ->
      linter.clearDeprecations()
      linter.checkSyntaxStylesheet(css, {
        packageName: "the-package",
        sourcePath: "index.less"
      })
      expect(linter.getDeprecations()["the-package"]["index.less"]).toContain({message})

    it "suggests using the :host psuedo-selector", ->
      expectDeprecation(
        ".editor .cursor",
        "Target the `:host` psuedo-selector in addition to the `editor` class for forward-compatibility"
      )

    it "doesn't log a deprecation if the :host selector is in use in the stylesheet", ->
      linter.checkSyntaxStylesheet("""
        .editor span, :host span {
          color: black;
        }
      """, {
        packageName: "the-package",
        sourcePath: "index.less"
      })

      expect(linter.getDeprecations()).toEqual({})

  describe "::check(selector, metadata)", ->
    expectDeprecation = (selector, message) ->
      linter.check(selector, {
        packageName: "the-package"
        sourcePath: "the-source-file"
      })

      expect(linter.getDeprecations()["the-package"]).toBeTruthy()
      expect(linter.getDeprecations()["the-package"]["the-source-file"]).toContain({message})

    it "doesn't deprecate up-to-date selectors", ->
      linter.check("atom-text-editor", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-sheet.less"
      })
      expect(linter.getDeprecations()).toEqual({})

    it "deprecates selectors targeting the `bracket-matcher` class itself", ->
      expectDeprecation(
        "my-region .bracket-matcher",
        "Use `.bracket-matcher .region` to select highlighted brackets."
      )

    it "deprecates selectors using the overlay class", ->
      expectDeprecation(
        ".overlay",
        "Use the selector `atom-panel[location=\"modal\"]` instead of the `overlay` class."
      )

    it "deprecates selectors using old panel classes", ->
      expectDeprecation(
        ".panel-top",
        "Use the selector `atom-panel[location=\"top\"]` instead of the `panel-top` class."
      )

    it "deprecates the mini class on editors", ->
      expectDeprecation(
        ".editor.mini",
        "Use the selector `.editor[mini]` to select mini-editors."
      )

    it "groups deprecations by package and source file", ->
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-stylesheet.less"
        lineNumber: 21
      })
      linter.check(".text-editor", {
        packageName: "the-package"
        sourcePath: "keymaps/the-keymap.cson"
        lineNumber: 22
      })
      linter.check(".pane", {
        packageName: "the-other-package"
        sourcePath: "menus/the-menu.cson"
        lineNumber: 23
      })
      linter.check(".pane-container", {
        packageName: "the-other-package"
        sourcePath: "menus/the-menu.cson"
        lineNumber: 24
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-stylesheet.less": [
            {
              lineNumber: 21
              message: "Use the `atom-workspace` tag instead of the `workspace` class."
            }
          ]
          "keymaps/the-keymap.cson": [
            {
              lineNumber: 22
              message: "Use the `atom-text-editor` tag instead of the `text-editor` class."
            }
          ]
        "the-other-package":
          "menus/the-menu.cson": [
            {
              lineNumber: 23
              message: "Use the `atom-pane` tag instead of the `pane` class."
            },
            {
              lineNumber: 24
              message: "Use the `atom-pane-container` tag instead of the `pane-container` class."
            }
          ]

    it "doesn't record the same deprecation twice", ->
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "index.less"
        lineNumber: 21
      })
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "index.less"
        lineNumber: 21
      })

      expect(linter.getDeprecations()["the-package"]["index.less"].length).toBe(1)

    it "doesn't record more than the given maximum deprecations per package", ->
      _.times 12, (i) ->
        linter.check(".workspace", {
          packageName: "the-package"
          sourcePath: "index.less"
          lineNumber: i
        })

      expect(linter.getDeprecations()["the-package"]["index.less"].length).toBe(10)
