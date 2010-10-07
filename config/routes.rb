ActionController::Routing::Routes.draw do |map|
  map.english 'english', :controller => 'language_switcher', :action => 'english'
  map.french 'francais', :controller => 'language_switcher', :action => 'french'
  map.contact 'contact-us', :controller => 'application', :action => 'contact'
  map.contact 'contactez-nous', :controller => 'application', :action => 'contact'
  map.help 'help', :controller => 'application', :action => 'help'
  map.help 'aide', :controller => 'application', :action => 'help'
end
