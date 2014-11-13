helpers = require "../src/helpers"

describe "Helpers", ->
  describe ".eachSelector(css, callback)", ->
    [selectorsYielded, callback] = []

    beforeEach ->
      selectorsYielded= []
      callback = (selector) -> selectorsYielded.push(selector)

    it "calls the callback with each selector in the stylesheet", ->
      helpers.eachSelector("""
      .class1 {
        color: red;
        font-size: 12px;
      }
      .class2 > .class3,
      .class4 .class5 {
        color: blue;
      }

      """, callback)

      expect(selectorsYielded).toEqual([
        ".class1",
        ".class2 > .class3",
        ".class4 .class5"
      ])

    it "works if there are no linebreaks", ->
      helpers.eachSelector(
        ".class1 { color: red; } .class2 { color: blue; }",
        callback
      )

      expect(selectorsYielded).toEqual([".class1", ".class2"])

  describe ".selectorHasClass(selector, klass)", ->
    it "returns true when the selector uses the class", ->
      expect(helpers.selectorHasClass(
        "div.the-class:first-child",
        "the-class"
      )).toBeTruthy()

      expect(helpers.selectorHasClass(
        "span.the-class",
        "the-class"
      )).toBeTruthy()

      expect(helpers.selectorHasClass(
        "span.the-class>other-tag",
        "the-class"
      )).toBeTruthy()

    it "returns false when the selector doesn't use the class", ->
      expect(helpers.selectorHasClass(
        "div.the-class-something",
        "the-class"
      )).toBeFalsy()

  describe ".selectorHasPsuedoClass(selector, klass)", ->
    it "returns true when the selector uses the psuedo-class", ->
      expect(helpers.selectorHasPsuedoClass(
        "div.the-class:the-psuedo-class",
        "the-psuedo-class"
      )).toBeTruthy()

      expect(helpers.selectorHasPsuedoClass(
        ":the-psuedo-class other-tag",
        "the-psuedo-class"
      )).toBeTruthy()

      expect(helpers.selectorHasPsuedoClass(
        ":the-psuedo-class>other-tag",
        "the-psuedo-class"
      )).toBeTruthy()

    it "returns false when the selector doesn't use the psuedo-class", ->
      expect(helpers.selectorHasPsuedoClass(
        "div:the-psuedo-class-something",
        "the-class"
      )).toBeFalsy()
