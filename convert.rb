#!/usr/bin/env ruby

# FIXME doesn't detect duplicates when ISBN10/ISBN13 conflict

require 'amazon_product'
require 'pp'
require 'date'
require 'optparse'

require './config.rb'

def prepare_request(locale='de')
  req = AmazonProduct[locale]
  req.configure do |c|
    c.key = $access_key_id
    c.secret = $secret_access_key
    c.tag = $affiliate_tag
  end
  
  req
end

def get_attrs_from_isbn(isbn)
  request_locales = $locales.clone
  while locale = request_locales.shift
    puts "Looking up ISBN #{isbn} in the #{locale} locale..."
    
    req_options = { 'IdType' => 'ISBN',
                    'SearchIndex' => 'All',
                    'ResponseGroup' => 'Large'}
    
    req = prepare_request(locale)
    resp = req.find(isbn, req_options)
    
    if resp.has_errors? then
      pp resp.errors if $debug
      puts "*** No valid response received."
      next
    end
    
    resp.to_hash
    resp = resp["Item"][0]['ItemAttributes']
    
    pp resp if $debug
    
    # store this for reference
    resp['__AmazonLocale'] = locale
    
    unless  resp.has_key?('Author') &&
            resp.has_key?('Title') &&
            resp.has_key?('Publisher') &&
            resp.has_key?('PublicationDate')   
      puts "*** A required key is missing from the response."
      next
    end
    
    begin
      resp['__PublicationYear'] = Date.parse(resp['PublicationDate']).year
    rescue ArgumentError => e
      # TODO try to parse the date before failing for this locale
      puts "*** The returned date is not valid."
      next
    end
    
    # all tests passed
    return resp 
  end
  
  puts "*** Locales exhausted; no valid information found."
  false
end

# We don't use the amazon provided ISBN because
# it isn't reliably contained in the response
def dokuwiki_line(item, isbn, *comment)
  comment.unshift(DateTime.now.to_s)
  comment = comment.join(' - ')
  
  # Dokuwiki apparently does not support escaping pipe
  # symbols, so we just delete them
  author = item['Author'].delete('|')
  title = item['Title'].delete('|')
  publisher = item['Publisher'].delete('|')
  
  line =  "| #{author} "
  line << "| #{title} "
  line << "| #{publisher} "
  line << "| #{item['__PublicationYear']} "
  line << "| #{isbn} "
  # the ugli dokuwiki part begins
  line << "<html><!-- #{comment} --></html> |"
end

# append a line to a file
def write_line(line)
  open('dokuwiki.txt', 'a') { |f|
    # newline
    f.puts
      
    # no newline
    f.print line
  }
end

def normalize_isbn(isbn)
  isbn.strip.delete('-')
end

def read_file
  isbn_list = []
  filename = 'dokuwiki.txt'
  
  return [] unless File.file?(filename)
  
  open(filename, 'r') { |f|
    while line = f.gets
      line.strip!
      
      # check whether this is a table row
      next unless line[0] == '|'
      line[0] = ''
      
      isbn = line.split('|').last.match(/^[[:space:]]*([[:digit:]]*)/)[1]
      isbn = normalize_isbn(isbn)
      next if isbn.empty?
      
      isbn_list << normalize_isbn(isbn)
    end
  }
  
  isbn_list
end

def isbn_exists?(isbn)
  $isbn_list.include?(isbn)
end

def harmonize_item(item)  
  ret = {}
  ret['Author'] = [*item['Author']].join(', ')
  ret['Title'] = item['Title']
  ret['Publisher'] = item['Publisher']
  ret['PublicationDate'] = item['PublicationDate']
  
  # our own fields

  ret['__AmazonLocale'] = item['__AmazonLocale']
  ret['__PublicationYear'] = item['__PublicationYear']
  
  ret
end

def print_item(item)
  puts "  Title: #{item['Title']}"
  puts "  Author: #{item['Author']}"
  puts "  Publisher: #{item['Publisher']}"
  puts "  PublicationDate: #{item['PublicationDate']}"
end

### OPTION PARSING
no_save = no_read = false
OptionParser.new do |opts|
  opts.banner = "Usage: convert.rb [options]"

  opts.on("-d", "Enable debug output") do |v|
    $debug = true
  end
  opts.on("-n", "Don't save to file") do |v|
    no_save = true
  end
  opts.on("-b", "--blind", "Don't read input file") do |v|
    no_read = true
  end
end.parse!

$isbn_list = []
$isbn_list = read_file unless no_read
# amazon locales are tried in this order until a useful result is found
# TODO set to ['us', 'de']
# $locales = ['us', 'de']
$locales = ['de', 'us']

puts "CERTAIN CONTENT THAT APPEARS IN THIS APPLICATION COMES FROM AMAZON EU S.à.r.l. THIS CONTENT IS PROVIDED ‘AS IS’ AND IS SUBJECT TO CHANGE OR REMOVAL AT ANY TIME.\n"

while true
  pp $isbn_list if $debug
  print "\n[Press RETURN to quit]\nISBN to lookup: "
  isbn = normalize_isbn(STDIN.gets)
  puts
  break if isbn.empty?
  
  if isbn_exists? isbn
    puts "*** This ISBN already exists in our library -- skipping"
    next
  end
    
  next unless item = get_attrs_from_isbn(isbn)
  pp item if $debug
  
  unless item = harmonize_item(item)
    puts "*** "
    next
  end
      
  puts "\nResult:"
  print_item item
  puts ""
  
  unless no_save then
    puts "*** Adding this book to the library."
    write_line( dokuwiki_line(item,
                              isbn,
                              "Amazon Locale: #{item['__AmazonLocale']}"))
    $isbn_list << isbn
  else
    puts "*** Saving to file disabled - doing nothing"
  end
end