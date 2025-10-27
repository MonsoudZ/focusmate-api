# frozen_string_literal: true

# Danger rules for code quality gates

# Rule: Changes in app/ require specs
if (git.modified_files + git.added_files).any? { |file| file.start_with?('app/') } &&
   (git.modified_files + git.added_files).none? { |file| file.start_with?('spec/') }
  fail "Changes in app/ require specs", sticky: false
end

# Rule: No debug/TODO markers in production code
debug_files = (git.modified_files + git.added_files).select do |file|
  file.start_with?('app/') && File.exist?(file)
end

debug_files.each do |file|
  content = File.read(file)
  if content.match?(/puts|p\s|binding\.pry|debugger|console\.log|TODO|FIXME|HACK/)
    line_number = content.lines.find_index { |line| line.match?(/puts|p\s|binding\.pry|debugger|console\.log|TODO|FIXME|HACK/) } + 1
    warn("Debug/TODO markers found in #{file}", file: file, line: line_number)
  end
end

# Rule: Large diffs should be reviewed carefully
large_files = (git.modified_files + git.added_files).select do |file|
  File.exist?(file) && `git diff --stat HEAD~1..HEAD -- "#{file}"`.split("\n").last&.include?("+") &&
  `git diff --stat HEAD~1..HEAD -- "#{file}"`.split("\n").last&.split("+")&.last&.to_i > 50
end

if large_files.any?
  warn("Large diffs detected in: #{large_files.join(', ')}. Please review carefully.", sticky: false)
end

# Rule: Test coverage should not decrease
# This would require integration with coverage reporting
# For now, just remind about coverage
if (git.modified_files + git.added_files).any? { |file| file.start_with?('app/') }
  message("Remember to check test coverage for modified files", sticky: false)
end
