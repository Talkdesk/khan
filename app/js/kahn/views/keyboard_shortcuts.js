Genghis.Views.KeyboardShortcuts = Backbone.View.extend({
    tagName:  'div',
    template: JST['partials/keyboard_shortcuts'],
    events: {
        'click a.close': 'hide'
    },
    initialize: function() {
        _.bindAll(this, 'render', 'show', 'hide', 'toggle');
        Mousetrap.bind('?', this.toggle);
        $('footer a.keyboard-shortcuts').click(this.show);
        this.render();
    },
    render: function() {
        this.$el.html(this.template()).modal({backdrop: true, keyboard: true, show: false});

        return this;
    },
    show: function(e) {
        e.preventDefault();
        this.$el.modal('show');
    },
    hide: function(e) {
        e.preventDefault();
        this.$el.modal('hide');
    },
    toggle: function() {
        this.$el.modal('toggle');
    }
});
