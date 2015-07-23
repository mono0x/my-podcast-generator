require 'bundler'
Bundler.require
require 'time'
require 'erb'

module Podcast
  class Program
    attr_reader :regexp, :output, :title
    def initialize(regexp:, output:, title: nil)
      @regexp = regexp
      @output = output
      @title = title
    end

    def file
      "#@output.xml"
    end

    def permalink(root)
      "#{root}/#{file}"
    end
  end

  class Part
    attr_reader :file, :path, :date, :title
    def initialize(file:, path:, date:, title:)
      @file = file
      @path = path
      @date = date
      @title = title
    end

    def permalink(root)
      "#{root}/#{ERB::Util.url_encode @file}"
    end

    def length
      File.size @path
    end
  end
end

require_relative 'config'

engine = Haml::Engine.new(open('feed.haml').read, format: :xhtml, attr_wrapper: '"', escape_html: true)

files = Dir.chdir(Podcast::Config::OUTPUT) { Dir['*.m4a'] }
Podcast::Config::PROGRAMS.each do |program|
  cond = /_#{program.regexp}\./
  matched_files = files.select {|file| file =~ cond }
  files = files - matched_files
  
  parts = matched_files.map {|file|
    file.match(/\A0*(?<year>\d+)-0*(?<month>\d+)-0*(?<day>\d+)_(?<title>.+)\.m4a\z/) {|m|
      date = Date.new(m[:year].to_i, m[:month].to_i, m[:day].to_i)
      title = m[:title]
      Podcast::Part.new(file: file, path: File.join(Podcast::Config::OUTPUT, file), date: date, title: title)
    }
  }.select {|part| part }.sort_by {|part| part.date }.reverse

  open(File.join(Podcast::Config::OUTPUT, program.file), 'w') do |f|
    f << engine.render(Object.new, root: Podcast::Config::ROOT, program: program, parts: parts)
  end
end
