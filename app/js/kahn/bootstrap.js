window.Genghis = {
    Models:      {},
    Collections: {},
    Views:       {},
    Templates:   {},
    defaults: {
        codeMirror: {
            mode:          'application/json',
            lineNumbers:   true,
            tabSize:       4,
            indentUnit:    4,
            matchBrackets: true
        }
    },
    boot: function() {
        window.app = new Genghis.Views.App({baseUrl: '/'});
        Backbone.history.start({pushState: true, root: '/'});
    }
};

