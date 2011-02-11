# THOSEKIDS.org
# fatDOG Scraper
#
# This script is designed to scrape the entire fatDOG site and import
# its content into a local database. Essentially, I'm playing with nibbler,
# Sequel, and planning to laugh a lot at my old, table-driven layout from
# early 2002.
#
# Colin McCloskey, Feb 2011
#

require 'rubygems'
require 'mysql2'
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'nibbler'

SITE_ROOT = "http://thosekids.org/fatdog/journal"
ARCHIVE_PAGE = File.join(SITE_ROOT, "journal_archive.asp")

# if false # TEMPORARY

DB = Sequel.mysql2(:host=>"127.0.0.1", :user=>"root", :database=>"fatdog_scrape")

# Load/Create the Links table holding reference links
unless DB.tables.include?(:links)
  DB.create_table :links do
    primary_key :id
    Integer :num
    String :href
    String :title
  end
  
  DB.create_table :articles do
    primary_key :id
    Integer :num
    String :href
    String :title
    String :author
    String :genre
    Text :body
    DateTime :created_at
  end
end
links_table = DB[:links]

class LinkItem < Nibbler
  # <A class="article" style="font-weight: bold;" href="journal_view.asp?Num=718">Elemental Game</A><BR>
  element './/@href' => :href
end

class ArchivePage < Nibbler
  # <A class="article" style="font-weight: bold;" href="journal_view.asp?Num=718">Elemental Game</A><BR>
  elements "a.article" => :links, :with=>LinkItem
end

puts "Parsing Archive Page #{ARCHIVE_PAGE}..."
archives = ArchivePage.parse open(ARCHIVE_PAGE)

archives.links.reverse.each_with_index do |link, idx|
  href = link.href
  title = link.doc.text
  old_num = href.split("?").last.split("=").last.to_i
  puts "  Importing #{idx}: Num=#{old_num} => #{link.doc.text}"
  result = links_table.insert(:num=>old_num, :title=>title, :href=>href)
  puts "  => Resulting Record: #{result.inspect}"
end


# end # TEMPORARY



class AuthorBox < Nibbler
  # <P align="center">
  #   <A href="author_profile.asp?Num=679&Author=Anthony Bacigalupo"><IMG border="0" src="images/authors/bacigalupo_a.gif" alt="Click for a profile of author Anthony Bacigalupo" width="100"></A><BR>
  #   Anthony Bacigalupo
  # </P>
  element "a//@href" => :href
end

class ArticleBody < Nibbler
  # <TD width="425" valign="top" class="body">
  #     <H1>Giant Freakin` Mosquito</H1>
  #     12.Jun.2006 { Crazy }
  #     <P>I was sitting here ...
  #   <P>Just as I was deciding...
  #   ...
  # </TD>
  element "h1" => :title
  elements "p" => :body  
end

class ArticlePage < Nibbler
  element "td.sidebar p:first" => :author, :with => AuthorBox
  element "td.body" => :article, :with => ArticleBody
end

MONTHS = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

articles_table = DB[:articles]

links_table.each do |article_link|
  #article_link = {}; article_link[:href] = "journal_view.asp?Num=17"

  # Integer :num
  # String :href
  # String :title
  # String :author
  # DateTime :created_at
  # String :genre
  # Text :body

  article_href = File.join(SITE_ROOT, article_link[:href])
  puts "Parsing Article Page #{article_href}..."
  page = ArticlePage.parse open(article_href)
  
  author_name = page.author.doc.text.strip
  title = page.article.title
  body = page.article.body.collect{|p| p.strip}.join("\n")
  date_match = page.article.doc.text.match /(\d+)\.(\w+)\.(\d+)/
  date_str = "#{date_match[2]}/#{date_match[1]}/#{date_match[3]}"
  date = Time.new( date_match[3].to_i, MONTHS.index(date_match[2])+1, date_match[1].to_i)
  genre_match = page.article.doc.text.match /{\s+(.+)\s+}/
  genre = genre_match[1]
  puts "  Author: #{author_name}"
  puts "  Title: #{title}"
  puts "  Date: #{date_str} => #{date}"
  puts "  Genre: #{genre}"
  puts "  Body: #{body.split(" ").length} words, #{body.length} characters"

  result = articles_table.insert(
    :num=>article_link[:num], 
    :href=>article_link[:href],
    :title=>title,
    :author=>author_name,
    :genre=>genre,
    :created_at=>date,
    :body=>body
  )
  puts "  => Resulting Record: #{result.inspect}"
end



