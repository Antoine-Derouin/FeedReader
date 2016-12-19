[DBus (name = "org.gnome.feedreader.FeedReaderArticleView")]
public class FeedReaderWebExtension : Object {

    private WebKit.DOM.Document m_doc;
    public signal void onClick(string path, int width, int height, string url);
    public signal void message(string message);

    [DBus (visible = false)]
    public void on_bus_aquired(DBusConnection connection)
    {
    	try
    	{
        	connection.register_object("/org/gnome/feedreader/FeedReaderArticleView", this);
        }
        catch(GLib.IOError e)
        {
        	warning("Could not register object");
        }
    }

    [DBus (visible = false)]
    public void on_page_created(WebKit.WebExtension extension, WebKit.WebPage page)
    {
        page.document_loaded.connect(() => {
        	onDocLoaded(page);
        });
        message("on_page_created");
    }

    private void onDocLoaded(WebKit.WebPage page)
    {
    	m_doc = page.get_dom_document();
    	message("onDocLoaded");
    }

    public void recalculate()
    {
    	message("recalculate");
	       var images = m_doc.get_images();
	          ulong count = images.get_length();

    	for(ulong i = 0; i < count; i++)
    	{
    		var image = (WebKit.DOM.HTMLImageElement)images.item(i);

            // if image was so huge it had to be replaced with a downscaled version
            if(image.has_attribute("FR_huge"))
            {
                addListener(image);
                continue;
            }

    		long nHeight = image.get_natural_height();
    		long nWidth = image.get_natural_width();
    		long height = image.get_height();
    		long width = image.get_width();

    		if(nHeight > 250 || nWidth > 250)
    		{
    			double hRatio = (double)height / (double)nHeight;
    			double wRatio = (double)width / (double)nWidth;
    			double threshold = 0.8;

    			if(hRatio <= threshold
                || wRatio <= threshold)
    			    addListener(image);
    			else
        			removeListener(image);
    		}
    	}
    }

    [DBus (visible = false)]
    private void addListener(WebKit.DOM.HTMLImageElement image)
    {
        ((WebKit.DOM.EventTarget) image).add_event_listener_with_closure("mouseover", on_enter, false);
        ((WebKit.DOM.EventTarget) image).add_event_listener_with_closure("mousemove", on_enter, false);
        ((WebKit.DOM.EventTarget) image).add_event_listener_with_closure("mouseout", on_leave, false);
        ((WebKit.DOM.EventTarget) image).add_event_listener_with_closure("click", on_click, false);
    }

    [DBus (visible = false)]
    private void removeListener(WebKit.DOM.HTMLImageElement image)
    {
        ((WebKit.DOM.EventTarget) image).remove_event_listener_with_closure("mouseover", on_enter, false);
        ((WebKit.DOM.EventTarget) image).remove_event_listener_with_closure("mousemove", on_enter, false);
        ((WebKit.DOM.EventTarget) image).remove_event_listener_with_closure("mouseout", on_leave, false);
        ((WebKit.DOM.EventTarget) image).remove_event_listener_with_closure("click", on_click, false);

        try
        {
            image.set_attribute("class", "");
        }
        catch(GLib.Error e)
        {
            stderr.printf("WebExtension.recalculate: %s", e.message);
        }
    }

    [DBus (visible = false)]
    private void on_enter(WebKit.DOM.EventTarget target, WebKit.DOM.Event event)
    {
    	try
    	{
    		var image = (WebKit.DOM.HTMLImageElement)target;
    		image.set_attribute("class", "clickable-img-hover");
    	}
    	catch(GLib.Error e)
    	{

    	}
    }

    [DBus (visible = false)]
    private void on_leave(WebKit.DOM.EventTarget target, WebKit.DOM.Event event)
    {
    	try
    	{
    		var image = (WebKit.DOM.HTMLImageElement)target;
    		image.set_attribute("class", "");
    	}
    	catch(GLib.Error e)
    	{

    	}
    }

    [DBus (visible = false)]
    public void on_click(WebKit.DOM.EventTarget target, WebKit.DOM.Event event)
    {
		event.prevent_default();
		var image = (WebKit.DOM.HTMLImageElement)target;

		string url = "";
		var parent = image.get_parent_element();
		if(parent.tag_name == "A")
			url = parent.get_attribute("href");

		string src = image.src;
		if(src.has_prefix("file://"))
            src = src.substring("file://".length);

        if(image.has_attribute("FR_huge"))
            src = image.get_attribute("FR_huge");

    	onClick(src, (int)image.natural_width, (int)image.natural_height, url);
    }
}

[DBus (name = "org.gnome.feedreader.FeedReaderArticleView")]
public errordomain FeedReaderWebExtensionError
{
    ERROR
}

[CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
void webkit_web_extension_initialize(WebKit.WebExtension extension)
{
    var server = new FeedReaderWebExtension();
    extension.page_created.connect(server.on_page_created);
    Bus.own_name(BusType.SESSION, "org.gnome.feedreader.FeedReaderArticleView", BusNameOwnerFlags.NONE,
        server.on_bus_aquired, null, () => { warning("Could not aquire name"); });
}
