module ContentViewerHelper

  include GetText
  include BlogHelper

  def number_of_comments(article)
    n = article.comments.size
    if n == 0
     _('No comments yet')
    else
     n_('One comment', '%{comments} comments', n) % { :comments => n }
    end
  end

  def article_title(article, args = {})
    title = article.abstract if article.kind_of?(UploadedFile) && article.image?
    title = article.title if title.blank?
    title = content_tag('h1', title, :class => 'title')
    if article.belongs_to_blog?
      unless args[:no_link]
        title = content_tag('h1', link_to(article.name, article.url), :class => 'title')
      end
      title << content_tag('span', _("%s, by %s - %s") % [show_date(article.published_at), link_to(article.author.name, article.author.url), link_to_comments(article)], :class => 'created-at')
    end
    title
  end

  def article_to_html(article)
    content = article.to_html(:page => params[:npage])
    return self.instance_eval(&content) if content.kind_of?(Proc)
    content
  end

  def link_to_comments(article)
    link_to( number_of_comments(article), article.url.merge(:anchor => 'comments_list') )
  end

end
