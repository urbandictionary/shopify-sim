require 'sinatra'
require 'liquid'
require 'json'
require 'sass'
require './standard_filters'
require './file_system'
require './image'
require 'awesome_print'
require 'active_support'

set :theme_path, ENV['THEME_PATH'] || 'skeleton-theme'

def parse_template(path)
  Liquid::Template.parse(File.read(path))
end

def yaml(path)
  YAML.load_file(path)
end

def theme_path(path)
  File.join(settings.theme_path, path)
end

def scss(source)
  Sass::Engine.new(source, syntax: :scss).render
end

def render_template(vars, path)
  template = parse_template(theme_path(path))
  template.render!(vars, {strict_variables: true, strict_filters: true})
end

def render_template_in_theme(vars, path)
  html = render_template(vars, path)
  render_template(vars.merge('content_for_layout' => html), 'layout/theme.liquid')
end

def yaml_merge(*paths)
  out = {}
  paths.each { |path| out.deep_merge!(yaml(path)) }
  out
end

before do
  Liquid::Template.error_mode = :strict
  Liquid::Template.register_filter StandardFilters
  Liquid::Template.file_system = FileSystem.new(settings.theme_path)
end

post '/cart/add' do
  params.awesome_inspect(html: true)
end

get '/' do
  vars = yaml_merge('index.yaml', 'settings.yaml')
  render_template_in_theme(vars, 'templates/product.liquid')
end

get '/files/*' do
  redirect 'http://lorempixel.com/800/150'
end

get '/assets/*' do
  raise 'Invalid path' if request.path.include?('..')

  if File.exist?(path = theme_path("#{request.path}.liquid"))
    content_type mime_type(File.extname(request.path))
    return parse_template(path).render!(yaml('settings.yaml'))
  end

  if File.exist?(path = theme_path("#{request.path.sub(/\.css$/, '')}.liquid"))
    content_type mime_type("css")
    return scss(parse_template(path).render!(yaml('settings.yaml')))
  end

  if File.exist?(path = theme_path(request.path))
    send_file path
  end

  halt 404
end