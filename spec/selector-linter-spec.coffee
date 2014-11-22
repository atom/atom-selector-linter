SelectorLinter = require "../src/selector-linter"
_ = require 'underscore-plus'

describe "SelectorLinter", ->
  linter = null

  beforeEach ->
    linter = new SelectorLinter

  describe "::checkPackage", ->
    fakePackage = null

    beforeEach ->
      fakePackage =
        name: "the-package"
        path: "/path/to/package"
        metadata: {}
        stylesheets: [
          ["/path/to/package/index.less", ".editor .cursor { background-color: blue; }"]
        ]
        menus: [
          ["/path/to/package/menus/the-menu.cson", {
            "context-menu":
              ".workspace":
                "The Command": "the-command"
          }]
        ],
        keymaps: [
          ["/path/to/package/keymaps/the-keymap.cson", {
            ".workspace":
              "cmd-x": "the-command"
          }]
        ]

    it "checks the package's menus", ->
      linter.checkPackage(fakePackage)
      expect(linter.getDeprecations()["the-package"]["menus/the-menu.cson"]).toEqual [
        {
          message: "Use the `atom-workspace` tag instead of the `workspace` class.",
          packagePath: "/path/to/package"
        }
      ]

    it "checks the package's keymaps", ->
      linter.checkPackage(fakePackage)
      expect(linter.getDeprecations()["the-package"]["keymaps/the-keymap.cson"]).toEqual [
        {
          message: "Use the `atom-workspace` tag instead of the `workspace` class.",
          packagePath: "/path/to/package"
        }
      ]

    describe "when the package is a syntax theme", ->
      beforeEach ->
        fakePackage.metadata["theme"] = "syntax"

      it "checks its stylesheets as syntax stylesheets", ->
        linter.checkPackage(fakePackage)
        expect(linter.getDeprecations()["the-package"]["index.less"]).toEqual [
          {
            message: "Target the `:host` psuedo-selector in addition to the `editor` class for forward-compatibility",
            packagePath: "/path/to/package"
          }
        ]

    describe "when the package is not a syntax theme", ->
      beforeEach ->
        fakePackage.metadata["theme"] = "ui"

      it "checks its stylesheets as UI stylesheets", ->
        linter.checkPackage(fakePackage)
        expect(linter.getDeprecations()["the-package"]["index.less"][0].message).toMatch(/atom-text-editor::shadow/)

      it "checks stylesheets with the editor context as syntax stylesheets", ->
        fakePackage.stylesheets.push([
          "/path/to/package/stylesheets/the-stylesheet.atom-text-editor.less",
          ".editor .cursor { color: red; }"
        ])

        linter.checkPackage(fakePackage)

        expect(linter.getDeprecations()["the-package"]["stylesheets/the-stylesheet.atom-text-editor.less"]).toEqual [
          {
            message: "Target the `:host` psuedo-selector in addition to the `editor` class for forward-compatibility",
            packagePath: "/path/to/package"
          }
        ]

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
        """
          Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension.
          If you want to target overlay elements, target them directly or as descendants of `atom-overlay` elements.
        """
      )
      expectDeprecation(
        ".text-editor .cursor { background-color: #aaa; }",
        """
          Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension.
          If you want to target overlay elements, target them directly or as descendants of `atom-overlay` elements.
        """
      )
      expectDeprecation(
        "atom-text-editor .cursor { background-color: #aaa; }",
        """
          Style elements within text editors using the `atom-text-editor::shadow` selector or the `.atom-text-editor.less` file extension.
          If you want to target overlay elements, target them directly or as descendants of `atom-overlay` elements.
        """
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

    it "doesn't suggest ::shadow unless children of the editor are being targeted", ->
      linter.checkUIStylesheet("""
        .editor-colors {
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
      expectDeprecation(
        ".editor-colors .cursor",
        "Target the `:host` psuedo-selector in addition to the `editor-colors` class for forward-compatibility"
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
        "Use the selector `atom-panel.modal` instead of the `overlay` class."
      )

    it "deprecates selectors using old panel classes", ->
      expectDeprecation(
        ".panel-top",
        "Use the selector `atom-panel.top` instead of the `panel-top` class."
      )

    it "deprecates the mini class on editors", ->
      expectDeprecation(
        ".editor.mini",
        "Use the selector `atom-text-editor[mini]` to select mini-editors."
      )

    it "groups deprecations by package and source file", ->
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "stylesheets/the-stylesheet.less"
      })
      linter.check(".text-editor", {
        packageName: "the-package"
        sourcePath: "keymaps/the-keymap.cson"
      })
      linter.check(".pane", {
        packageName: "the-other-package"
        sourcePath: "menus/the-menu.cson"
      })
      linter.check(".pane-container", {
        packageName: "the-other-package"
        sourcePath: "menus/the-menu.cson"
      })

      expect(linter.getDeprecations()).toEqual
        "the-package":
          "stylesheets/the-stylesheet.less": [
            {
              message: "Use the `atom-workspace` tag instead of the `workspace` class."
            }
          ]
          "keymaps/the-keymap.cson": [
            {
              message: "Use the `atom-text-editor` tag instead of the `text-editor` class."
            }
          ]
        "the-other-package":
          "menus/the-menu.cson": [
            {
              message: "Use the `atom-pane` tag instead of the `pane` class."
            },
            {
              message: "Use the `atom-pane-container` tag instead of the `pane-container` class."
            }
          ]

    it "doesn't record the same deprecation twice", ->
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "index.less"
      })
      linter.check(".workspace", {
        packageName: "the-package"
        sourcePath: "index.less"
      })

      expect(linter.getDeprecations()["the-package"]["index.less"].length).toBe(1)
