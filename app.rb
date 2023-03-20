require "logger"
Bundler.require
Dotenv.load

def main
  notion.database_query(database_id: ENV["NOTION_DATABASE_ID"]) do |page|
    page.results.each do |item|
      logger.info("Processing page (id = #{item.id})")

      release_url = item.properties["Discogs URL"].url
      if release_url.nil?
        logger.info("Page (id = #{item.id}) doesn't have Discogs URL. Skipping")
        next
      end

      logger.info("Getting release info from Discogs: #{release_url}")
      release_id = release_url[%r{/release/(\d+)}, 1]
      release = discogs.get_release(release_id)


      logger.info("Updating page (id = #{item.id})")
      properties = properties_from_release(release)
      notion.update_page(page_id: item.id, properties: properties)

      logger.info("Sleeping for throttling")
      sleep 3
    end
  end
end

def properties_from_release(release)
  title_str = release.title
  artists_str = release.artists.map {|artist| artist.name.gsub(/ \(\d+\)$/, "") }.uniq.join(", ")
  tracklist_str = release.tracklist.map {|track| "#{track.position} #{track.title}"}.join("\n")[0, 2000]
  genres_arr = release.genres ? release.genres.map {|genre| {name: genre.gsub(/Folk, World, & Country/, "Folk / World / Country") } } : nil
  styles_arr = release.styles ? release.styles.map {|style| {name: style.gsub(/Folk, World, & Country/, "Folk / World / Country") } } : nil
  properties = {
    "Title" => [{"text" => {"content" => title_str}}],
    "Artists" => [{"text" => {"content" => artists_str}}],
    "Tracklist" => [{"text" => {"content" => tracklist_str}}],
  }

  if genres_arr
    properties["Genres"] = genres_arr
  end
  if styles_arr 
    properties["Styles"] = styles_arr
  end

  properties
end

def notion
  @notion ||= Notion::Client.new(
    token: ENV["NOTION_API_TOKEN"]
  )
end

def discogs
  @discogs ||= Discogs::Wrapper.new(
    "My awesome web app"
  )
end

def logger
  @logger ||= Logger.new(STDOUT)
end

# Monkey-patch for discogs-wrapper gem
require "uri"
require "cgi"
module URI
  def self.escape(str)
    CGI.escape(str)
  end
end

main
