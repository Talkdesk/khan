Genghis.Views.Alert = Backbone.View.extend({
    tagName:  'div',
    template: JST['partials/alert'],
    events: {
        'click a.close': 'destroy'
    },
    initialize: function() {
        _.bindAll(this, 'render', 'remove', 'destroy');

        this.model.bind('change',  this.render);
        this.model.bind('destroy', this.remove);
    },
    render: function() {
        this.$el.html(this.template(this.model));
        return this;
    },
    destroy: function() {
        this.model.destroy();
    },
    remove: function() {
        this.$el.remove();
    }
});
