#!/usr/bin/env ruby
require 'fileutils'
require 'securerandom'

# Simple script to add DebugLogger.swift to the Xcode project

project_file = 'SystemAudioRecorder/SystemAudioRecorder.xcodeproj/project.pbxproj'
source_file_path = 'SystemAudioRecorder/SystemAudioRecorder/DebugLogger.swift'
source_file_name = 'DebugLogger.swift'

# Read the project file
content = File.read(project_file)

# Generate UUIDs for the file reference and build file
file_ref_uuid = SecureRandom.uuid.delete('-').upcase[0..23]
build_file_uuid = SecureRandom.uuid.delete('-').upcase[0..23]

puts "Adding #{source_file_name} to project..."
puts "File Reference UUID: #{file_ref_uuid}"
puts "Build File UUID: #{build_file_uuid}"

# Find the main group's children section (where source files are listed)
files_section_pattern = /(\/\* SystemAudioRecorder \*\/ = \{[^}]*children = \([^)]*)(WAVWriter\.swift \/\* WAVWriter\.swift \*\/;)/m

if content =~ files_section_pattern
  # Add file reference to the group
  content.sub!(files_section_pattern) do |match|
    "#{$1}#{file_ref_uuid} /* #{source_file_name} */,\n\t\t\t\t#{$2}"
  end
  puts "✓ Added to file group"
else
  puts "✗ Could not find files section"
  exit 1
end

# Add PBXFileReference entry
file_ref_entry = "\t\t#{file_ref_uuid} /* #{source_file_name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{source_file_name}; sourceTree = \"<group>\"; };\n"
content.sub!(/(\/\* End PBXFileReference section \*\/)/, "#{file_ref_entry}\\1")
puts "✓ Added PBXFileReference"

# Add PBXBuildFile entry
build_file_entry = "\t\t#{build_file_uuid} /* #{source_file_name} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* #{source_file_name} */; };\n"
content.sub!(/(\/\* End PBXBuildFile section \*\/)/, "#{build_file_entry}\\1")
puts "✓ Added PBXBuildFile"

# Add to PBXSourcesBuildPhase (compile sources)
sources_build_pattern = /(\/\* Sources \*\/ = \{[^}]*files = \([^)]*)(WAVWriter\.swift in Sources \*\/,)/m
if content =~ sources_build_pattern
  content.sub!(sources_build_pattern) do |match|
    "#{$1}#{build_file_uuid} /* #{source_file_name} in Sources */,\n\t\t\t\t#{$2}"
  end
  puts "✓ Added to Sources build phase"
else
  puts "✗ Could not find Sources build phase"
  exit 1
end

# Write back
File.write(project_file, content)
puts "\n✅ Successfully added #{source_file_name} to project!"
