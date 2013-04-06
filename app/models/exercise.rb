require "rexml/document"
include REXML

class Exercise < ActiveRecord::Base
  belongs_to :course_instance
  has_many :groups, :order => 'name, id'
  has_many :categories, {:dependent => :destroy, :order => 'position'}

  validates_presence_of :name

  def max_points
    # TODO
    1
  end
  
  # Feedback grouping options: exercise, sections, categories

  
  # Assigns submissions evenly to the given users
  # submission_ids: array of submission ids
  # users: array of user objects
  # exclusive: previous assignments are erased
  def assign(submission_ids, user_ids)
    #submissions = Submission.find(submission_ids)

    counter = 0
    n = user_ids.size

    return if n < 1

    submission_ids.each do |submission_id|
      assistant_id = user_ids[counter % n]

      Review.create(:user_id => assistant_id, :submission_id => submission_id)
      #if exclusive
      #  submission.assign_to_exclusive(assistant)
      #else
        #submission.assign_to(assistant)
      #end

      counter += 1
    end
  end

  def rubric_content
    JSON.parse(self.rubric)
  end
  
  # Populates the rubric with some example data.
  # This erases the existing rubric.
  def initialize_example
    # TODO
  end

  #{ "version":2,
  #  "pages":[
  #    {"id":0,"name":"Sivu 1",
  #     "criteria":[{"id":0,"name":"Kriteeri 1.1","phrases":[{"id":0,"text":"Mikä meni hyvin\nToinen rivi","category":"Hyvää"},{"id":1,"text":"<b>Mikä meni huonosti</b>","category":"Kehitettävää"},{"id":8,"text":"Jotain muuta","category":"Muuta"}]},{"id":1,"name":"Kriteeri 1.2","phrases":[{"id":8,"text":"Olipa hyvä","category":"Hyvää"},{"id":8,"text":"Olipa huono","category":"Kehitettävää"}]}]},
  #  ],
  
  # "grades":["Failed",1,2,3,4,5],
  # "gradingMode":"average",
  # "feedbackCategories":["Hyvää","Kehitettävää","Muuta"],
  # "finalComment":"Loppukaneetti\n<b>Toinen rivi</b>"
  # }
  
  # Load rubric from an XML file.
  # This erases the existing rubric.
  def load_xml1(file)
    # Parse XML
    doc = REXML::Document.new(file)

    page_counter = 0
    criterion_counter = 0
    phrase_counter = 0
    pages = []
    rubric = {version: 2, pages: pages}
    
    # Categories
    positive_caption_element = XPath.first(doc, "/rubric/positive-caption")
    positive_caption = 'Strengths'
    positive_caption = positive_caption_element.text.strip if positive_caption_element and positive_caption_element.text

    negative_caption_element = XPath.first(doc, "/rubric/negative-caption")
    negative_caption = 'Weknesses'
    negative_caption = negative_caption_element.text.strip if negative_caption_element and negative_caption_element.text

    neutral_caption_element = XPath.first(doc, "/rubric/neutral-caption")
    neutral_caption = 'Other comments'
    neutral_caption = neutral_caption_element.text.strip if neutral_caption_element and neutral_caption_element.text

    rubric['feedbackCategories'] = [{id: 0, name: positive_caption}, {id: 1, name: negative_caption}, {id: 2, name: neutral_caption}]
    
    # Final comment
    final_comment_element = XPath.first(doc, "/rubric/final-comment")
    finalcomment = ''
    finalcomment = final_comment_element.text.strip if final_comment_element and final_comment_element.text
    
    rubric['finalComment'] = finalcomment
    
    rubric['gradingMode'] = 'average'

    # Categories
    doc.each_element('rubric/category') do |category|
      # Sections
      category.each_element('section') do |section|
        criteria = []
        
        new_page = {id: page_counter, name: section.attributes['name'], criteria: criteria}
        new_page['weight'] = section.attributes['weight'] if section.attributes['weight']
        pages << new_page
        page_counter += 1

        #Items
        section.each_element('item') do |item|
          phrases = []
          new_criterion = {id: criterion_counter, name: item.attributes['name'], phrases: phrases}
          criteria << new_criterion
          criterion_counter += 1

          # Phrases
          item.each_element('phrase') do |phrase|
            case phrase.attributes['type']
            when 'Neutral'
              categoryId = 2
            when 'Bad'
              categoryId = 1
            else # Good
              categoryId = 0
            end
            
            phrases << {id: phrase_counter, text: phrase.text.strip, category: categoryId}
            phrase_counter += 1
          end

          # Item grading options
          #item.each_element('grade') do |grading_option|
          #  igo_counter += 1
          #  new_grading_option = ItemGradingOption.new({:text => grading_option.text.strip, :position => igo_counter})
          #  new_item.item_grading_options << new_grading_option
          #end
        end # items

        # Section grading options
        rubric['grades'] = grades = []
        section.each_element('grade') do |grading_option|
          grades << grading_option.text.strip
        end

      end # sections
    end # categories
    
    self.rubric = rubric.to_json
  end


  def generate_xml
    doc = Document.new
    root = doc.add_element 'rubric'

    # Categories
    categories.each do |category|
      category_element = root.add_element 'category', {'name' => category.name, 'weight' => category.weight}

      # Section
      category.sections.each do |section|
        section_element = category_element.add_element 'section', {'name' => section.name, 'weight' => section.weight}

        # Items
        section.items.each do |item|
          item_element = section_element.add_element 'item', {'name' => item.name}

          # Phrases
          item.phrases.each do |phrase|
            phrase_element = item_element.add_element 'phrase', {'type' => phrase.feedbacktype}
            phrase_element.add_text phrase.content
          end

          # Item grades
          item.item_grading_options.each do |grading_option|
            item_go_element = item_element.add_element 'grade'
            item_go_element.add_text grading_option.text
          end

        end

        # Section grades
        section.section_grading_options.each do |grading_option|
          section_go_element = section_element.add_element 'grade', {'points' => grading_option.points}
          section_go_element.add_text grading_option.text
        end

      end
    end

    # Properties
    final_comment = root.add_element 'final-comment'
    final_comment.add_text self.finalcomment

    positive_caption = root.add_element 'positive-caption'
    positive_caption.add_text self.positive_caption

    negative_caption = root.add_element 'negative-caption'
    negative_caption.add_text self.negative_caption

    neutral_caption = root.add_element 'neutral-caption'
    neutral_caption.add_text self.neutral_caption

    feedback_grouping = root.add_element 'feedback-grouping'
    feedback_grouping.add_text self.feedbackgrouping

    # Write the XML, intendation = 2 spaces
    output = ""
    doc.write(output, 2)

    return output
  end

  # Returs a grade distribution histogram [[grade,count],[grade,count],...]
  def grade_distribution(grader = nil)
    if grader
      reviews = Review.find(:all, :joins => 'FULL JOIN submissions ON reviews.submission_id = submissions.id ', :conditions => [ 'exercise_id = ? AND user_id = ? AND calculated_grade IS NOT NULL', self.id, grader.id ])
    else
      reviews = Review.find(:all, :joins => 'FULL JOIN submissions ON reviews.submission_id = submissions.id ', :conditions => [ 'exercise_id = ?  AND calculated_grade IS NOT NULL', self.id ])
    end

    # group reviews by grade  [ [grade,[review,review,...]], [grade,[review,review,...]], ...]
    reviews_by_grade = reviews.group_by{|review| review.calculated_grade}

    # count reviews in each bin [ [grade, count], [grade,count], ... ]
    histogram = reviews_by_grade.collect { |grade, stats| [grade,stats.size] }

    # sort by grade
    histogram.sort { |x,y| x[0] <=> y[0] }
  end

  # Assign submissions to assistants
  # csv: student, assistant
  def batch_assign(csv)
    counter = 0

    # Make an array of lines
    array = csv.split(/\r?\n|\r(?!\n)/)

    Exercise.transaction do
      array.each do |line|
        parts = line.split(',',2).map { |s| s.strip }
        next if parts.size < 1

        submission_studentnumber = parts[0]
        assistant_studentnumber = parts[1]

        # Find submissions that belong to the student
        submissions = Submission.find(:all, :conditions => [ "groups.exercise_id = ? AND users.studentnumber = ?", self.id, submission_studentnumber], :joins => {:group => :users})
        grader = User.find_by_studentnumber(assistant_studentnumber)

        next unless grader

        # Assign those submissions
        submissions.each do |submission|
          counter += 1 if submission.assign_once_to(grader)
        end
      end

      return counter
    end
  end

  def archive(options = {})
    only_latest = options.include? :only_latest

    archive = Tempfile.new('rubyric-archive')

    # Make a temp directory. It is deleted automatically after the block returns.
    Dir.mktmpdir("rubyric") do |temp_dir|
      # Create the actual content directory so that it has a sensible name in the archive
      content_dir_name = "rubyric-exercise#{self.id}"
      Dir.mkdir "#{temp_dir}/#{content_dir_name}"

      # Add contents
      groups.each do |group|
        group.submissions.each do |submission|

          # Link the submissionn
          source_filename = submission.full_filename
          target_filename = "#{temp_dir}/#{content_dir_name}/#{group.name}-#{submission.created_at.strftime('%Y%m%d%H%M%S')}"
          target_filename << ".#{submission.extension}" unless submission.extension.blank?

          if File.exist?(source_filename)
            FileUtils.ln_s(source_filename, target_filename)
          end

          # Take only one file per group?
          if only_latest
            break
          end
        end
      end

      # Archive the folder
      #puts "tar -zcf #{archive.path()} #{content_dir_name}"
      system("tar -zc --directory #{temp_dir} --file #{archive.path()} #{content_dir_name}")
    end

    return archive
  end

  # Creates example submissions for existing groups.
  def create_example_submissions
    example_submission_file = "#{SUBMISSIONS_PATH}/example.pdf"
    example_submission_file = nil unless File.exists?(example_submission_file)
    #example_submission_file = nil

    submission_path = "#{SUBMISSIONS_PATH}/#{self.id}"
    begin
      FileUtils.makedirs(submission_path) if example_submission_file
    rescue
      example_submission_file = nil
    end

    # Create submissions
    self.course_instance(true).groups.each do |group|
      submission = Submission.create(:exercise_id => self.id, :group_id => group.id, :extension => 'pdf', :filename => 'example.pdf')

      FileUtils.ln_s(example_submission_file, "#{submission_path}/#{submission.id}.pdf") if example_submission_file
    end
  end
  
  def disk_space
    path = "#{SUBMISSIONS_PATH}/#{self.id}"
    `du -s #{path}`.split("\t")[0].to_i
  end
  
  # Will be run in background by delayed job
  def self.deliver_reviews(review_ids)
    # Send all reviews
    reviews = Review.find(:all, :conditions => {:id => review_ids, :status => 'mailing'})

    logger.info "Sending #{reviews.size} reviews"

    reviews.each do |review|
      Mailer.deliver_review(review)
    end
  end
end
