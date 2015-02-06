Genghis.Views.Databases = Genghis.Views.BaseSection.extend({
    el: 'section#databases',
    template: JST['partials/databases'],
    rowView: Genghis.Views.DatabaseRow,
    formatTitle: function(model) {
        return model.id ? (model.id + ' Databases') : 'Databases';
    }
});
