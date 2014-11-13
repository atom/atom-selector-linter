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

  describe "::checkStylesheet(css, metadata)", ->
    it "records deprecations in the CSS", ->
      linter.checkStylesheet("""
        .workspace {
          color: blue;
        }
      """, {
        packageName: "the-package"
        sourcePath: "stylesheets/the-stylesheet.less"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-stylesheet.less": [{
            message: "Use the `atom-workspace` tag instead of the `workspace` class."
          }]

  describe "::check(selector, metadata)", ->
    describe "when the selector is not deprecated", ->
      it "doesn't record a deprecation", ->
        linter.check(".some-workspace", {
          packageName: "the-package"
          sourcePath: "stylesheets/the-sheet.less"
          lineNumber: 21
        })
        linter.check(".workspace-something", {
          packageName: "the-package"
          sourcePath: "stylesheets/the-sheet.less"
          lineNumber: 22
        })

        expect(linter.getDeprecations()).toEqual({})

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

    it "recognizes selectors targeting the `bracket-matcher` class", ->
      linter.check("my-region .bracket-matcher", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-sheet.less"
        lineNumber: 22
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-sheet.less": [{
            lineNumber: 22
            message: "Use `.bracket-matcher .region` to select highlighted brackets."
          }]

    it "recognizes selectors targeting overlays", ->
      linter.check(".overlay", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-sheet.less"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-sheet.less": [{
            message: "Use the selector `atom-panel[location=\"modal\"]` instead of the `overlay` class."
          }]

    it "recognizes selectors targeting panels", ->
      linter.check(".panel-top", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-sheet.less"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-sheet.less": [{
            message: "Use the selector `atom-panel[location=\"top\"]` instead of the `panel-top` class."
          }]

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
