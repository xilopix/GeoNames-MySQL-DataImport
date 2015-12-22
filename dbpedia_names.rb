#!/usr/bin/ruby
#  2 # -*- encoding : utf-8 -*-

require 'csv'
require 'open-uri'

if ARGV.length != 2
  puts "Usage: fixer.rb <geoname_alternatenames> <dbpedia_interlanguage_links>"
  exit
end

alternatenames_path = ARGV[0]
dbpedia_interlanguage_links_path = ARGV[1]

links_en = Hash.new { |h, k| h[k] = [] }
links_fr = Hash.new { |h, k| h[k] = [] }
max = 0
STDERR.puts "Parse alternateNames and reformat wikipedia lines"
CSV.foreach(alternatenames_path, col_sep:"\t", quote_char: "\x00").each do |line|
  lang = line[2]
  name = line[3]
  link = 0
  i = line[0].to_i
  max = i if i > max
  # Fix dbpedia urls
  if /^https?:\/\/(.+?)\.wikipedia\.org\/wiki\/(.*)$/ =~ name
    lang, name =  $~[1..2]
    name[0] = name[0].capitalize if name.length>0
    links_en[line[1]] << name if lang == 'en'
    name = URI.decode(name)
    name.encode!('utf-8', 'utf-8',  :invalid => :replace)
    link = 1
  end
  name.gsub!(/ /, '_')
  links_fr[line[1]] << name if lang == 'fr'
  line[2] = lang
  line[3] = name
  line << link
  puts line.join("\t") #if link
end

STDERR.puts "Parse dbpedia interlanguage links"
dbpedia = {}
triple = %r{
  ^
  <http://dbpedia\.org/resource/(.*?)>
  \s
  <.*?>
  \s
  <http://fr\.dbpedia.org/resource/(.*?)>
  \s\.$
}x

  File.open(dbpedia_interlanguage_links_path).each_line do |line|
  if triple =~ line
   en = $~[1]
   fr = $~[2]
   en.gsub!(/\\u([0-9A-F]+)/) {|r| [$1.hex].pack('U')}
   fr.gsub!(/\\u([0-9A-F]+)/) {|r| [$1.hex].pack('U')}
   dbpedia[en] = fr
  end
end

STDERR.puts "Add french dbpedia links"
links_en.each do |geoname_id, names|
  names.each do |name|
    name_fr = dbpedia[name]
    if !name_fr.nil?
      if links_fr.has_key?(geoname_id) && links_fr[geoname_id].include?(name_fr)
        STDERR.puts "#{geoname_id}: #{name_fr}: #{links_fr[geoname_id]}"
        next
      end
      if links_fr.has_key?(geoname_id)
        STDERR.puts "#{geoname_id}::: #{name_fr}: #{links_fr[geoname_id]}"
      end
      max += 1
      line = [max, geoname_id, 'fr', name_fr, 0, 0, 0, 0, 1]
      puts line.join("\t")
    end
  end
end
