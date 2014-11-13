classRegexpCache = {}
psuedoClassRegexpCache = {}

module.exports =
  eachSelector: (css, fn) ->
    for selectors, i in css.split(/{|}/) when i % 2 is 0
      for selector in selectors.split(",")
        selector = selector.trim()
        fn(selector) if selector

  selectorHasClass: (selector, klass) ->
    classRegexpCache[klass] ?= new RegExp("\\.#{klass}([ >\.:]|$)")
    classRegexpCache[klass].test(selector)

  selectorHasPsuedoClass: (selector, klass) ->
    psuedoClassRegexpCache[klass] ?= new RegExp("\\:#{klass}([ >\.:]|$)")
    psuedoClassRegexpCache[klass].test(selector)
