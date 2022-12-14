#!/usr/bin/env ruby

KEEPASS_JAVA_URL = 'https://github.com/jorabin/KeePassJava2.git'.freeze

PATCH1 = '/patches/0001-Fix-Base64-imports.patch'.freeze
PATCH2 = '/patches/0002-Fix-Recycle-Bin-detection.patch'.freeze
PATCH3 = '/patches/0003-Implement-protected-properties.patch'.freeze

SUCCESS = 'success'.freeze
FAILURE = 'failure'.freeze

def read_current_path
  current_path = `cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P`.strip

  if current_path.empty?
    puts "Failed to locate project directory, try to 'cd' into project and run script again"
    exit 1
  end

  current_path
end

def directory_exist?(path)
  `[ -d #{path} ] && echo #{SUCCESS} || echo #{FAILURE}`.strip == SUCCESS
end

def clone_keepass_java_project
  path = "#{read_current_path}/tmp/KeePassJava2"
  already_cloned = directory_exist?(path)

  if !already_cloned
    `git clone #{KEEPASS_JAVA_URL} "#{path}"`
  end

  path
end

def checkout_tag(repo_path, tag_name)
  puts "Checkout tag: #{tag_name}"
  branch_name = "#{tag_name}-branch"
  `cd "#{repo_path}"`

  branches = `cd "#{repo_path}" && git branch`.gsub('*', '').split("\n").map(&:strip)

  if !branches.index(branch_name).nil?
    # If branch already exist
    `cd "#{repo_path}" && git checkout --force master && git branch -d #{branch_name}`
  end

  `cd "#{repo_path}" && git checkout "tags/#{tag_name}" -b "#{branch_name}"`
end

def remove_directory_if_exist(path)
  puts "Removing directory: #{path}"
  `[ -d #{path} ] && rm -r "#{path}"`
end

def copy_sources(src_path, dst_path)
  puts "copy sources from: #{src_path} to #{dst_path}"
  successfully = `cp -r "#{src_path}" "#{dst_path}" && echo #{SUCCESS} || echo #{FAILURE}`.strip == SUCCESS
  if !successfully
    puts 'Failed to copy files'
    exit 1
  end
end

def apply_patch(patc_file_path)
  puts "Applying patch: #{patc_file_path}"
  `cd "#{read_current_path}"`

  applied = `git apply "#{patc_file_path}" && echo "#{SUCCESS}"`.strip == SUCCESS
  if applied
    puts 'Successfully applied'
  else
    puts "Failed to apply path file: #{patc_file_path}"
    exit 1
  end
end

def build_library(flavor, library_file_path)
  command = "./gradlew :KeePassJava2-android:assemble#{flavor}"
  library_module_name = "KeePassJava2-android:#{flavor}"

  puts "Assembling library: #{library_module_name}"
  puts "   executed command: #{command}"

  `cd "#{read_current_path}"`
  `[ -f #{library_file_path} ] && rm -r "#{library_file_path}"`
  successfully = `#{command} > /dev/null 2>&1 && echo #{SUCCESS} || echo #{FAILURE}`.strip == SUCCESS
  if successfully
    puts "#{library_module_name} is assembled successfully"
  else
    puts "Failed to assemble module: #{library_module_name}"
    exit 1
  end
end

def main
  current_path = read_current_path

  # clone KeePassJava2 project from github
  keepass_java_path = clone_keepass_java_project
  checkout_tag(keepass_java_path, 'KeePassJava2-2.1.4')

  # copy sources to the libs/*
  remove_directory_if_exist("#{current_path}/KeePassJava2-android/src/main/java/org")
  copy_sources("#{keepass_java_path}/database/src/main/java/", "#{current_path}/KeePassJava2-android/src/main")
  copy_sources("#{keepass_java_path}/simple/src/main/java/", "#{current_path}/KeePassJava2-android/src/main")
  copy_sources("#{keepass_java_path}/kdbx/src/main/java/", "#{current_path}/KeePassJava2-android/src/main")
  copy_sources("#{keepass_java_path}/kdb/src/main/java/", "#{current_path}/KeePassJava2-android/src/main")

  # apply pathces
  apply_patch(current_path + PATCH1)
  apply_patch(current_path + PATCH2)
  apply_patch(current_path + PATCH3)

  # build library
  aar_debug_path = "#{current_path}/KeePassJava2-android/build/outputs/aar/KeePassJava2-android-debug.aar"
  aar_release_path = "#{current_path}/KeePassJava2-android/build/outputs/aar/KeePassJava2-android-release.aar"
  build_library('Debug', aar_debug_path)
  build_library('Release', aar_release_path)

  puts 'SUCCESS'
end

main
