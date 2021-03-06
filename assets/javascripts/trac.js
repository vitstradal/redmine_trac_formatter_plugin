// Elements definition ------------------------------------

// bold 
jsToolBar.prototype.elements.bold = {
        type: 'button',
        title: 'Bold',
        fn: {
                wiki: function() { this.singleTag("*", "*") }
        }
}

// em
jsToolBar.prototype.elements.em = {
        type: 'button',
        title: 'Emphasized',
        fn: {
                wiki: function() { this.singleTag("''", "''") }
        }
}

// code
jsToolBar.prototype.elements.em = {
        type: 'button',
        title: 'Emphasized',
        fn: {
                wiki: function() { this.singleTag("''", "''") }
        }
}

// kbd
jsToolBar.prototype.elements.kbd = {
        type: 'button',
        title: 'Keyboard',
        fn: {
                wiki: function() { this.singleTag('`', '`') }
        }
}


// spacer
jsToolBar.prototype.elements.space1 = {type: 'space'}

// headings
jsToolBar.prototype.elements.h1 = {
        type: 'button',
        title: 'Heading 1',
        fn: {
                wiki: function() { 
                  this.encloseLineSelection('= ', ' =',function(str) {
                    str = str.replace(/^=+\s+/, '')
                    return str;
                  });
                }
        }
}
jsToolBar.prototype.elements.h2 = {
        type: 'button',
        title: 'Heading 2',
        fn: {
                wiki: function() { 
                  this.encloseLineSelection('== ', ' ==',function(str) {
                    str = str.replace(/^=+\.\s+/, '')
                    return str;
                  });
                }
        }
}
jsToolBar.prototype.elements.h3 = {
        type: 'button',
        title: 'Heading 3',
        fn: {
                wiki: function() { 
                  this.encloseLineSelection('=== ', ' ===',function(str) {
                    str = str.replace(/^=+\s+/, '')
                    return str;
                  });
                }
        }
}
// spacer
jsToolBar.prototype.elements.space2 = {type: 'space'}


// ul
jsToolBar.prototype.elements.ul = {
        type: 'button',
        title: 'Unordered list',
        fn: {
                wiki: function() {
                        this.encloseLineSelection('','',function(str) {
                                str = str.replace(/\r/g,'');
                                if (!str.match(/(\n|^)(?!\(\d+\))[^\s\*]/)) {
                                  return str;
                                }
                                str = str.replace(/(\n|^)/g, "$1  ");
                                str = str.replace(/(\n|^)  (?!\(\d+\))([^\s\*])/g, "$1* $2");
                                return str;
                        });
                }
        }
}

// ol
jsToolBar.prototype.elements.ol = {
        type: 'button',
        title: 'Ordered list',
        fn: {
                wiki: function() {
                        this.encloseLineSelection('','',function(str) {
                                str = str.replace(/\r/g,'');
                                var i = 0;
                                var non_list_lines = str.replace(/(\n|^)\d+\.[^\n]*/g, '');

                                if (non_list_lines == '') {
                                  // every line start with: 1. something
                                  // so: make it order
                                  str = str.replace(/(\n|^)\d+\.\s/, function(m, p1) {
                                    return p1 + (++i) + ". ";
                                  });
                                  return str;
                                }
                                str = str.replace(/(\n|^)/g, "$1  ");
                                str = str.replace(/(\n|^)  /g, function(m, p1) {
                                    return p1 + (++i) + ". ";
                                });
                                return str;
                        });
                }
        }
}

// spacer
jsToolBar.prototype.elements.space3 = {type: 'space'}

// pre
jsToolBar.prototype.elements.pre = {
        type: 'button',
        title: 'Preformatted',
        fn: {
                wiki: function() { this.singleTag("{{{\n", "\n}}}\n") }
//              wiki: function() {
//                      this.encloseLineSelection('','',function(str) {
//                              str = str.replace(/\r/g,'');
//                              return str.replace(/(\n|^) *([^\n]*)/g,"$1 $2");
//                      });
//              }
        }
}

/*
// unpre
jsToolBar.prototype.elements.unpre = {
        type: 'button',
        title: 'Un-preformatted',
        fn: {
                wiki: function() {
                        this.encloseLineSelection('','',function(str) {
                                str = str.replace(/\r/g,'');
                                return str.replace(/(\n|^) *([^\n]*)/g,"$1$2");
                        });
                }
        }
}
*/
// spacer
jsToolBar.prototype.elements.space4 = {type: 'space'}

// wiki page
jsToolBar.prototype.elements.link = {
        type: 'button',
        title: 'Wiki link',
        fn: {
                wiki: function() { this.encloseSelection("[[", "]]") }
        }
}
// image
jsToolBar.prototype.elements.img = {
        type: 'button',
        title: 'Image',
        fn: {
          wiki: function() { this.encloseSelection("[[Image(", ")]]") }
        }
}
