SelectorLinter = require "../src/selector-linter"

describe "SelectorLinter", ->
  linter = null

  beforeEach ->
    linter = new SelectorLinter

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
        "the-package": [
          {
            sourcePath: "keymaps/the-keymap.cson"
            message: "Use the `atom-workspace` tag instead of the `workspace` class."
          }
        ]

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
        "the-package": [
          {
            sourcePath: "keymaps/the-keymap.cson"
            message: "Use the `atom-text-editor` tag instead of the `text-editor` class."
          }
        ]

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
        "the-package": [
          {
            sourcePath: "stylesheets/the-stylesheet.less"
            message: "Use the `atom-workspace` tag instead of the `workspace` class."
          }
        ]

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

    describe "when the selector uses a deprecated class", ->
      it "records a deprecation for the package", ->
        linter.check(".workspace > span", {
          packageName: "the-package"
          sourcePath: "stylesheets/the-stylesheet.less"
          lineNumber: 21
        })
        linter.check("div.text-editor.other-class > span", {
          packageName: "the-package"
          sourcePath: "keymaps/the-keymap.cson"
          lineNumber: 22
        })
        linter.check(".pane:first-child span", {
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
          "the-package": [
            {
              sourcePath: "stylesheets/the-stylesheet.less"
              lineNumber: 21
              message: "Use the `atom-workspace` tag instead of the `workspace` class."
            }
            {
              sourcePath: "keymaps/the-keymap.cson"
              lineNumber: 22
              message: "Use the `atom-text-editor` tag instead of the `text-editor` class."
            }
          ]

          "the-other-package": [
            {
              sourcePath: "menus/the-menu.cson"
              lineNumber: 23
              message: "Use the `atom-pane` tag instead of the `pane` class."
            }
            {
              sourcePath: "menus/the-menu.cson"
              lineNumber: 24
              message: "Use the `atom-pane-container` tag instead of the `pane-container` class."
            }
          ]

    describe "when the selector targets the bracket-matcher highlight", ->
      it "records a deprecation", ->
        linter.check("my-region .bracket-matcher", {
          packageName: "the-package"
          sourcePath: "stylesheets/the-sheet.less"
          lineNumber: 22
        })

        expect(linter.getDeprecations()).toEqual
          "the-package": [
            {
              sourcePath: "stylesheets/the-sheet.less"
              lineNumber: 22
              message: "Use `.bracket-matcher .region` to select highlighted brackets."
            }
          ]
