MutationObserver = require('./observers/mutation_observer.coffee')
Serializer = require('./serializer.coffee')
MouseObserver = require('./observers/mouse_observer.coffee')
ScrollObserver = require('./observers/scroll_observer.coffee')
ViewportObserver = require('./observers/viewport_observer.coffee')
TextSelectionObserver = require('./observers/text_selection_observer.coffee')
UrlObserver = require('./observers/url_observer.coffee')

class Recorder
  constructor: (options) ->
    @serializer = new Serializer()
    @rootElement = options.rootElement
    @client = new options.Client(options.document, @rootElement)

    @observers = {
      mutation: new MutationObserver(@serializer)
      mouse: new MouseObserver()
      scrolling: new ScrollObserver()
      viewport: new ViewportObserver()
      url: new UrlObserver()
      selection: new TextSelectionObserver(@serializer)
    }



  initialize: ->
    @observers.scrolling.initialize(window)
    @observers.url.initialize(window)
    @observers.mutation.initialize(@rootElement)
    @observers.mouse.initialize(window)
    @observers.viewport.initialize(window)
    @observers.selection.initialize(document) #seems to only be available on the document :-/

  startRecording: ->
    @client.startRecording( (sessionId) =>
      @sessionId = sessionId
      @_bindObserverEvents(@observers)
      @initialize()
      for key, v of @observers
        v.observe()
    )

  stopRecording: ->
    for key, v of @observers
      v.disconnect()


  _processSelectionObject: (data, fn) ->
    data.anchorNode = @observers.mutation.serializer.knownNodesMap.get(data.anchorNode) if data.anchorNode
    data.focusNode = @observers.mutation.serializer.knownNodesMap.get(data.focusNode) if data.focusNode
    fn(data)

  _bindObserverEvents: (observers) ->

    observers.url.on('initialize', (info)=>@client.setInitialURL(info))
    observers.url.on('urlChanged', (info)=>@client.onURLChanged(info))


    observers.scrolling.on('initialize', (info) => @client.setInitialScrollState(info))
    observers.scrolling.on('scroll', (info) => @client.onScroll(info))

    observers.mutation.on('initialize', => @client.setInitialMutationState.apply(@client, arguments))
    observers.mutation.on('change', => @client.onMutation.apply(@client, arguments))

    observers.viewport.on('initialize', (info) => @client.setInitialViewportState(info))
    observers.viewport.on('resize', (info) => @client.onWindowResize(info))

    observers.selection.on('initialize', (data)=> @_processSelectionObject(data, =>
      @client.setInitialSelection.apply(@client, arguments))
    )
    observers.selection.on('select', (data)=> @_processSelectionObject(data, =>
      @client.onSelect.apply(@client, arguments))
    )

    observers.mouse.on('mouse_clicked', (data)=> @client.onMouseClick(data))
    observers.mouse.on('mouse_moved', (position)=> @client.onMouseMove(position))


module.exports = Recorder
