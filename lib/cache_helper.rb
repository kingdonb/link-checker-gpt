module CacheHelper
  def self.get_cache_path(url)
    uri = URI(url)
    cache_path = File.join("cache", uri.path)
    # If the path doesn't have a common file extension, treat it as a directory.
    unless cache_path.match(/\.(html|xml|json|txt|js|css|jpg|jpeg|png|gif)$/i)
      cache_path = File.join(cache_path, "index.html")
    end
    cache_path
  end

  def self.write_to_cache(url, content, status)
    cache_path = get_cache_path(url)
    data = { content: content, status: status }
    File.write(cache_path, JSON.dump(data))
  end

  def self.read_from_cache(url)
    cache_path = get_cache_path(url)
    data = JSON.parse(File.read(cache_path))
    [data["content"], data["status"]]
  end
end
