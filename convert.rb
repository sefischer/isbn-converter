#!/usr/bin/env ruby

# FIXME doesn't detect duplicates when ISBN10/ISBN13 conflict

require 'amazon_product'
require 'term/ansicolor'
require 'pp'
require 'date'
require 'optparse'

require './config.rb'

class Color
  extend Term::ANSIColor
end

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
      status_message("No valid response received.", :warn)
      next
    end

    resp.to_hash
    resp = resp["Item"][0]['ItemAttributes']

    pp resp if $debug

    # store this for reference
    resp['__AmazonLocale'] = locale

    resp['__Author'] = nil
    if resp.has_key?('Author') then
      resp['__Author'] = [*resp['Author']].join(', ')
    elsif resp.has_key?('Creator') then
      # resp['Creator'] can be an array of creators
      if resp['Creator'].class == Hash
        resp['Creator'] = [resp['Creator']]
      end
      resp['Creator'].each do |creator|
        if creator['Role'] == 'Editor' || creator['Role'] == 'Herausgeber'
          resp['__Author'] = creator['__content__'] + ' (Hrsg.)'
        end
      end
    end

    unless resp['__Author']
      status_message("No author information found.", :warn)
      next
    end

    unless  resp.has_key?('Title') &&
            resp.has_key?('Publisher') &&
            resp.has_key?('PublicationDate')
      status_message("A required key is missing from the response.", :warn)
      next
    end

    begin
      resp['__PublicationYear'] = Date.parse(resp['PublicationDate']).year
    rescue ArgumentError
      # TODO try to parse the date before failing for this locale
      # check for a date in the format of 2005-12 or 2005
      regex = /^([[:digit:]]{4})(-[[:digit:]]{1,2})?$/
      if match = regex.match(resp['PublicationDate'])
        resp['__PublicationYear'] = match[1]
      else
        status_message("The returned date is not valid.", :warn)
        next
      end
    end

    # all tests passed
    return resp
  end

  status_message("Locales exhausted; no valid information found.", :err)
  false
end

def status_message(message,level)
  colors = {:info => Color.blue, :warn => Color.yellow, :success => Color.green, :err => Color.red}
  color = colors[level]
  puts color + "*** " + Color.clear + message

  print "\a" if level == :err
end

# We don't use the amazon provided ISBN because
# it isn't reliably contained in the response
def dokuwiki_line(item, isbn, *comment)
  comment.unshift(DateTime.now.to_s)
  comment = comment.join(' - ')

  # Dokuwiki apparently does not support escaping pipe
  # symbols, so we just delete them
  author = item['__Author'].delete('|')
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

      isbn = line.split('|').last.match(/^[[:space:]]*([[[:digit:]]-]*)/)[1]
      isbn = normalize_isbn(isbn)
      next if isbn.empty?

      isbn_list << normalize_isbn(isbn)
    end
  }

  status_message("Read #{isbn_list.length} entries from file.", :success)

  isbn_list
end

def isbn_exists?(isbn)
  $isbn_list.include?(isbn)
end

def print_item(item)
  puts "  Title: #{item['Title']}"
  puts "  Author: #{item['__Author']}"
  puts "  Publisher: #{item['Publisher']}"
  puts "  Publication Year: #{item['__PublicationYear']}"
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
# $locales = ['us', 'de']
$locales = ['de', 'us']

puts "\nCERTAIN CONTENT THAT APPEARS IN THIS APPLICATION COMES FROM AMAZON EU S.à.r.l. THIS CONTENT IS PROVIDED ‘AS IS’ AND IS SUBJECT TO CHANGE OR REMOVAL AT ANY TIME.\n"

while true
  pp $isbn_list if $debug
  print "\n[Press RETURN to quit]\nISBN to lookup: "
  isbn = normalize_isbn(STDIN.gets)
  puts
  break if isbn.empty?

  if isbn_exists? isbn
    status_message( 'This ISBN already exists in our library -- skipping',
                    :info)
    next
  end

  next unless item = get_attrs_from_isbn(isbn)
  pp item if $debug

  status_message("Got a result", :success)
  print_item item
  puts ""

  unless no_save then
    status_message("Adding this book to the library.", :info)
    write_line( dokuwiki_line(item,
                              isbn,
                              "Amazon Locale: #{item['__AmazonLocale']}"))
    $isbn_list << isbn
  else
    status_message("Saving to file disabled - doing nothing", :info)
  end
end