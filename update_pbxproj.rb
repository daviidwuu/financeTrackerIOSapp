require 'xcodeproj'
project_path = 'FinanceTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find group for Profile/Settings
settings_group = project.main_group.find_subpath(File.join('FinanceTracker', 'Views', 'Profile', 'Settings'), true)
target = project.targets.first

# Add files to the group and target
files_to_add = [
  'AccountSettingsView.swift',
  'AppearanceSettingsView.swift',
  'NotificationsSettingsView.swift',
  'PrivacySettingsView.swift',
  'HelpCenterView.swift',
  'AboutView.swift'
]

files_to_add.each do |file_name|
  file_path = "FinanceTracker/Views/Profile/Settings/#{file_name}"
  
  # Check if file is already in the project
  ref = settings_group.files.find { |f| f.path == file_name }
  if ref.nil?
    ref = settings_group.new_file(file_name)
    target.add_file_references([ref])
    puts "Added #{file_name} to project"
  else
    puts "#{file_name} already exists in project"
  end
end

# Remove ProfileSubviews.swift from project
profile_group = project.main_group.find_subpath(File.join('FinanceTracker', 'Views', 'Profile'), true)
profile_subviews_ref = profile_group.files.find { |f| f.path == 'ProfileSubviews.swift' }
if profile_subviews_ref
  profile_subviews_ref.remove_from_project
  puts "Removed ProfileSubviews.swift from project"
end

project.save
