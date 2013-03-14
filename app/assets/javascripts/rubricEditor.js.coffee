#= require knockout-2.2.1
#= require bootstrap
#= require jquery.ui.sortable
#= require knockout-sortable-0.7.3

# TODO:
# grades
# grading mode
# final comment
#
# TODO
# preview (grader)
# preview (mail)
# page weights
# quality levels
# cut'n'paste
# feedback grouping


ko.bindingHandlers.editable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    $(element).click ->
      valueAccessor().editorActive(true)
  
  
  update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    options = valueAccessor()
    el = $(element)

    if ko.utils.unwrapObservable(options.editorActive)
      type = ko.utils.unwrapObservable(options.type) || 'textfield'
      original_value = ko.utils.unwrapObservable(options.value)
      
      #ko.utils.registerEventHandler element, "change", () ->
      #  observable = editorActive;
      #  observable($(element).datepicker("getDate"));
    
      # Create editor
      if 'textarea' == type
        input = $("<textarea>#{original_value}</textarea>")
      else
        input = $("<input type='textfield' value='#{original_value}' />")

      # Event handlers
      okHandler = (event) =>
        options.value(new String(input.val()))
        options.editorActive(false)
        event.stopPropagation()

      cancelHandler = (event) ->
        options.value(new String(original_value))
        options.editorActive(false)
        event.stopPropagation()

      # Make buttons
      ok = $('<button>OK</button>').click(okHandler)
      cancel = $('<button>Cancel</button>').click(cancelHandler)

      # Attach event handlers
      input.keyup (event) ->
        switch event.keyCode
          when 13
            okHandler(event) unless type == 'textarea'
          when 27 then cancelHandler(event)

        # Prevent esc from closing the dialog
        event.stopPropagation()

      # Close on blur
      #input.blur(cancelHandler)

      # Stop propagation of clicks to prevent reopening the editor when clicking the input
      input.click (event) -> event.stopPropagation()

      # Replace original text with the editor
      el.empty()
      el.append(input)
      el.append('<br />') if 'textarea' == type
      el.append(ok)
      el.append(cancel)

      # Set focus to the editor
      input.focus()
      input.select()

      # handle disposal (if KO removes by the template binding)
      #ko.utils.domNodeDisposal.addDisposeCallback(element, () ->
        # TODO
        #$(element).editable("destroy")
      #)
    
    else
      placeholder = ko.utils.unwrapObservable(options.placeholder) || '-'
      value = ko.utils.unwrapObservable(options.value)
      
      # Show placeholder if value is empty
      value = placeholder if placeholder && (!value || value.length < 1)
      
      # Escape nasty characters
      value = value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')

      el.html(value)

}


class Page
  constructor: (@rubricEditor) ->
    @id = ko.observable()
    @name = ko.observable('')
    @criteria = ko.observableArray()
    @grades = ko.observableArray()
    @editorActive = ko.observable(false)
    
    #if data
    #  this.load_json(data)
    #else
    #  this.initializeDefault()
      
    @tabUrl = ko.computed(() ->
        return "#page-#{@id()}"
      , this)
    @tabId = ko.computed(() ->
        return "page-#{@id()}"
      , this)
    @tabLinkId = ko.computed(() ->
        return "page-#{@id()}-link"
      , this)
    
    
    #@element = false  # The tab content div


  initializeDefault: () ->
    @id(@rubricEditor.nextPageId())
    @name('Untitled page')

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 1')
    @criteria.push(criterion)

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 2')
    @criteria.push(criterion)


  load_json: (data) ->
    @id(@rubricEditor.nextPageId(parseInt(data['id'])))
    @name(data['name'])

    # Load criteria
    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this, criterion_data)
      @criteria.push(criterion)

    # Load grades
    if data['grades']
      for grade in data['grades']
        @grades.push(new Grade(grade, @grades))


  to_json: ->
    criteria = []
    grades = []

    for criterion in @criteria()
      criteria.push(criterion.to_json())

    for grade in @grades()
      grades.push(grade.to_json())

    return {id: @id(), name: @name(), criteria: criteria, grades: grades}

    # TODO: Criteria can be dropped into page tabs
#     @tab.droppable({
#       accept: '.criterion',
#       hoverClass: 'dropHover',
#       drop: (event) => @dropCriterionToSection(event)
#       tolerance: 'pointer'
#     })


  showTab: ->
    $('#' + @tabLinkId()).tab('show')


  #
  # Deltes this page
  #
  deletePage: ->
    @rubricEditor.pages.remove(this)
    
    # Activate first tab
    $('#tab-settings-link').tab('show')

  #
  # Event handler: User clicks the 'Create criterion' button
  #
  clickCreateCriterion: (event) ->
    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

    criterion.activateEditor()

  createGrade: () ->
    grade = new Grade('', @grades)
    @grades.push(grade)
    grade.activateEditor()


  activateEditor: ->
    @editorActive(true)


class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @name = ko.observable('')
    @phrases = ko.observableArray()
    @editorActive = ko.observable(false)
    
    if data
      this.load_json(data)
    else
      this.initializeDefault()
    
    
  initializeDefault: () ->
    @id = @rubricEditor.nextCriterionId()
    
    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What went well")
    phrase.category("Strengths")
    @phrases.push(phrase)

    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What could be improved")
    phrase.category("Weaknesses")
    @phrases.push(phrase)
    
    
  load_json: (data) ->
    @name(data['name'])
    @id = @rubricEditor.nextCriterionId(parseInt(data['id']))

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, this, phrase_data)
      @phrases.push(phrase)


  to_json: ->
    phrases = []

    for phrase in @phrases()
      phrases.push(phrase.to_json())

    return {id: @id, name: @name(), phrases: phrases}

  
  activateEditor: ->
    @editorActive(true)

  clickCreatePhrase: ->
    phrase = new Phrase(@rubricEditor, this)
    @phrases.push(phrase)

    phrase.activateEditor()


  deleteCriterion: ->
    @page.criteria.remove(this)


class Phrase
  constructor: (@rubricEditor, @criterion, data) ->
    @content = ko.observable('')
    @category = ko.observable()
    @editorActive = ko.observable(false)
    
    if data
      this.load_json(data)
    else
      @id = @rubricEditor.nextPhraseId()


  load_json: (data) ->
    @id = @rubricEditor.nextPhraseId(parseInt(data['id']))
    @content(data['text'])

    category = @rubricEditor.feedbackCategoriesIndex[data['category']]
    @category(category)


  to_json: ->
    category = if @category() then @category().value() else ''
    return {id: @id, text: @content(), category: category}

  activateEditor: ->
    @editorActive(true)

  deletePhrase: ->
    @criterion.phrases.remove(this)


class Grade
  constructor: (data, @container) ->
    @value = ko.observable(data || '')
    @editorActive = ko.observable(false)
  
  to_json: () ->
    return @value()
  
  activateEditor: ->
    @editorActive(true)
    
  deleteGrade: () ->
    return unless @container
    @container.remove(this)
  

class RubricEditor

  constructor: () ->
    @saved = true
    @pageIdCounter = 0
    @criterionIdCounter = 0
    @phraseIdCounter = 0
    
    @gradingMode = ko.observable('average')
    @feedbackCategories = ko.observableArray()
    @feedbackCategoriesIndex = {}              # string => Grade, needed for setting phrase categories when loading rubric
    @finalComment = ko.observable('')
    @pages = ko.observableArray()

    @url = $('#rubric-editor').data('url')

    $(window).bind 'beforeunload', => return "You have unsaved changes. Leave anyway?" unless @saved

    this.setHelpTexts()

    this.loadRubric(@url)

  setHelpTexts: ->
    $('.help-hover').each (index, element) =>
      helpElementName = $(element).data('help')

      $(element).mouseenter ->
        $('#context-help > div').hide()
        $("##{helpElementName}").show()

  nextPageId: (id) ->
    if id
      @pageIdCounter = id if id > @pageIdCounter
      return @pageIdCounter
    else
      return @pageIdCounter++

  nextCriterionId: (id) ->
    if id 
      @criterionIdCounter = id if id > @criterionIdCounter
      return @criterionIdCounter
    else
      return @criterionIdCounter++

  nextPhraseId: (id) ->
    if id
      @phraseIdCounter = id if id > @phraseIdCounter
      return @phraseIdCounter
    else
      return @phraseIdCounter++

  initializeDefault: ->
    @gradingMode('average')
    @finalComment('')
    @feedbackCategories([new Grade('Strengths'),new Grade('Weaknesses'),new Grade('Other comments')])

    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)


  #
  # Creates a new rubric page
  #
  clickCreatePage: ->
    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)
    page.showTab()
    page.activateEditor()

  clickCreateCategory: ->
    @feedbackCategories.push('')
    # TODO: activate editor

  #
  # Loads the rubric by AJAX
  #
  loadRubric: (url) ->
    $.ajax
      type: 'GET'
      url: url
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        this.parseRubric(data)

  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseRubric: (data) ->
    if !data
      this.initializeDefault()
    else
      @gradingMode(data['gradingMode'] || 'average')
      @finalComment(data['finalComment'] || '')
      
      if data['feedbackCategories']
        for category in data['feedbackCategories']
          grade = new Grade(category)
          @feedbackCategories.push(grade)
          @feedbackCategoriesIndex[category] = grade
          
      else
        @feedbackCategories([new Grade('Strengths'),new Grade('Weaknesses'),new Grade('Other comments')])

      for page_data in data['pages']
        page = new Page(this)
        page.load_json(page_data)
        @pages.push(page)
    
    ko.applyBindings(this)


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  clickSaveRubric: () ->
    # Generate JSON
    pages = []
    for page in @pages()
      pages.push(page.to_json())

    categories = []
    for category in @feedbackCategories()
      categories.push(category.to_json())

    json = {
      version: 1
      gradingMode: @gradingMode()
      finalComment: @finalComment()
      feedbackCategories: categories
      pages: pages
    }
    json_string = JSON.stringify(json)

    # AJAX call
    $.ajax
      type: 'PUT',
      url: @url,
      data: {rubric: json_string},
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        @saved = true
        alert('Changes saved')


  #
  # Callback for AJAX errors
  #
  onAjaxError: (jqXHR, textStatus, errorThrown) ->
    switch textStatus
      when 'timeout'
        alert('Server is not responding')
      else
        alert(errorThrown)


jQuery ->
  new RubricEditor
