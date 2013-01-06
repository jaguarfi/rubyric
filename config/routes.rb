Rubyric::Application.routes.draw do
  resource :session do
    get 'shibboleth'
  end

  resource :frontpage, :only => [:show], :controller => 'frontpage'

  resources :users do
    collection do
      get :search
    end
  end

  resources :courses do
    #post 'add_teachers'
    #post 'remove_selected_teachers'

    resources :course_instances, :only => [:new, :create, :update]
    resources :teachers, :controller => 'courses/teachers'
  end

  resources :course_instances, :only => [:show, :edit, :destroy] do
    resources :exercises, :only => [:new, :create, :update]
    
    resource :instructors, :controller => 'course_instances/instructors'
    resource :reviewers, :controller => 'course_instances/reviewers'
    
    resource :students, :controller => 'course_instances/students'
    resource :groups, :controller => 'course_instances/groups'
    
    get :create_example_groups
  end

  resources :exercises, :only => [:show, :edit, :destroy] do
    get 'results'
    get 'statistics'
    get 'batch_assign'
    post 'batch_assign'
    get 'archive'
    post 'delete_reviews'
    
    get :create_example_submissions

    resources :submissions, :controller => 'exercises' do
      collection do
        post :assign
      end
    end

    resource :rubric, :only => [:show, :edit, :update] do
      member do
        get 'download'
        get 'upload'
      end
    end

    resources :groups
  end

  match 'groups/:id/join/:token' => 'groups#join', :as => :join_group

  resources :invitations, :id => /[^\/]+/ do
#     member do
#       get 'teacher'
#       get 'assistant'
#       get 'group'
#     end
  end
  
  resources :submissions do
    member do
      get :review
    end
  end

  resources :reviews do
    member do
      get :finish
      put :update_finish
    end
  end

  resources :feedbacks, :only => [:edit]


  #match '/exercise/new/:instance' => 'exercises#new'
  match '/submit/:exercise' => 'submissions#new', :as => :submit

  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout

  root :to => "frontpage#show"

  # Install the default routes as the lowest priority.
  #match ':controller(/:action(/:id(.:format)))'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  #match ':controller(/:action(/:id(.:format)))'
end
