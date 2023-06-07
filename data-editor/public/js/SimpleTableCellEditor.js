window.onload = function () {
    if (!window.jQuery) {
        throw "jQuery is not loaded";
    }
};

class SimpleTableCellEdition {

    constructor(elem, _cellParams) {

        this.Elem       = elem;
        this.oldContent = $(elem).html();
        this.oldValue   = _cellParams.internals.extractValue(elem);
        this.cellParams = _cellParams;
    }

}

class SimpleTableCellEditor {


    constructor(_tableId, _params) {

        var _instance = this;

        _instance.EditionEndOrigin = {
            OutsideTable: 1,
            AnotherCell: 2
        };

        // Add collection for the classes for processing later
        _instance.editableClasses = [];

        this.tableId        = _tableId ? _tableId : 'table' 
        this.active         = true;
        this.params         = _instance._GetExtendedEditorParams(_params); // Load default params over given ones
        this.CellEdition    = null; // CellEdition contains the current edited cell

        // If DataTable : Handling DataTable reload event
        // this._TryHandleDataTableReloadEvent();

        // Handle click outside table to end edition
        $(document).on("mouseup", function (e) {

            var container = $(`#${_instance.tableId}`);

            if (!container.is(e.target) && container.has(e.target).length === 0) {
                _instance._FreeCurrentCell(_instance.EditionEndOrigin.OutsideTable);
            }

            return;
        });
    }


    SetEditable(elem, _cellParams, excludeClass="uneditable") {

        var _instance = this;

        if (!_instance._isValidElem(elem))
            return;

        var cellParams = _instance._GetExtendedCellParams(_cellParams);


        // If click on td (not already in edit ones)
        $(elem).on('click', function (evt) {

            if(!_instance.active) 
                return;
            
            if ( $(this).hasClass(_instance.params.inEditClass) ) 
                return;

            if ( $(this).hasClass(excludeClass) ) 
                return;

            if ( $(this).closest('table').hasClass(excludeClass) ) 
                return

            _instance._EditCell(this, cellParams);

        });


        $(elem).on('keydown', function (event) {

            if(!_instance.active)
                return;

            if (!$(this).hasClass(_instance.params.inEditClass))
                return;

            _instance._HandleKeyPressed(event, this, cellParams);

        });

    }


    SetEditableClass(editableClass, _cellParams) {

        var _instance = this;

        var cellParams = _instance._GetExtendedCellParams(_cellParams);

        // Add class to editableClass
        _instance.editableClasses.push(`.${editableClass}`)

        // If click on td (not already in edit ones)
        $(`#${_instance.tableId}`).on('click', `td.${editableClass}:not(.${_instance.params.inEditClass})`, function () {

            if(!_instance.active)
                return;

            _instance._EditCell(this, cellParams);
        });


        $(`#${_instance.tableId}`).on('keydown', `td.${editableClass}.${_instance.params.inEditClass}`, function (event) {
            
            if(!_instance.active)
                return;

            _instance._HandleKeyPressed(event, this, cellParams);
        });

    }

    Toggle(_active){

        if(typeof(_active) === 'undefined')
            _active = !this.active;

            this.active = _active;

    }

    // Private methods
    _HandleKeyPressed(event, elem, cellParams) {
        var _instance = this;

        // Variables that can be used in the function
        var which = event.which
        var shift = event.shiftKey
        var colIndex = $(elem).closest('td').index()
        var rowIndex = $(elem).closest('tr').index()
        var moveNext = false
        var movePrevious = false
        var moveDown = false
        var moveUp = false

        // Only run arrow or tab logic if navigation is enabled and there is at least one editableClasses
        if ((_instance.params.navigation && _instance.editableClasses.length !== 0) || _instance.tableId == "table") {
            // Get arrow key behavior
            if (cellParams.behaviour.arrowKeyCauseCursorMove && shift) {
                if (which === 39)
                    moveNext = true
                else if (which === 37)
                    movePrevious = true
                else if (which === 40)
                    moveDown = true
                else if (which === 38)
                    moveUp = true
            }
            // Get tab key behavior
            if (cellParams.behaviour.tabKeyCauseCursorMove) {
                if (which === 9) {
                    if (!shift)
                        moveNext = true
                    else
                        movePrevious = true
                }
            }

            if (moveNext || movePrevious || moveDown || moveUp) {
                event.preventDefault()
                if (_instance.tableId == "table") {
                    // if _instance.tableId is set to 'table', make navigation act on all td-tags
                    var $tableElementsArray = $(elem).closest('table').find('td')
                }
                else {
                    var $tableElementsArray = $(elem).closest('table').find(_instance.editableClasses.join(','))
                }

                // TODO: Optimize the creation of $visibleBoxes
                var visibleBoxes = []
                $.each($tableElementsArray, function () {
                    if ($(this).is(":visible")) {
                        visibleBoxes.push(this);
                    }
                })
                var $visibleBoxes = $(visibleBoxes)
                var elemIndex = $visibleBoxes.index($(elem))
                var $obj
                if (moveNext) {
                    elemIndex++
                    if (elemIndex === $visibleBoxes.length)
                        elemIndex = 0
                }
                else if (movePrevious) {
                    elemIndex--
                    if (elemIndex < 0)
                        elemIndex = $visibleBoxes.length - 1
                } else if (moveDown || moveUp) {
                    // TODO: Optimize the creation of $colBoxes
                    var colBoxes = []
                    $.each($visibleBoxes, function () {
                        if ($(this).closest('td').index() === colIndex) {
                            colBoxes.push(this);
                        }
                    })
                    var $colBoxes = $(colBoxes)
                    var myIndex = $colBoxes.index($(elem))
                    if (moveDown) {
                        myIndex++
                        if (myIndex === $colBoxes.length)
                            myIndex = 0
                    }
                    else if (moveUp) {
                        myIndex--
                        if (myIndex < 0)
                            myIndex = $colBoxes.length - 1
                    }
                    var elemIndex = $visibleBoxes.index($($colBoxes[myIndex]))
                }
                $obj = $($visibleBoxes[elemIndex])
                // Assumed user wanted save if they are moving around the grid
                this._FreeCell(elem, cellParams, true)

                // Show next element
                $obj.trigger("click")
                return
            }
        }

        // If validation key is pressed -> end edit cell (keep changes)
        if (cellParams.keys.validation.includes(which))
            this._FreeCell(elem, cellParams, true);

        // If cancellation key is pressed -> end edit cell (do not keep changes)
        else if (cellParams.keys.cancellation.includes(which))
            this._FreeCell(elem, cellParams, false);

    }

    _EditCell(elem, cellParams) {

        // Triggering before entering edition mode event
        var onEditEnterEvent = this._FireOnEditEnterEvent(elem);

        if (onEditEnterEvent.isDefaultPrevented())
            return;

        // We free up hypothetical previous cell
        this._FreeCurrentCell(this.EditionEndOrigin.AnotherCell);

        this.CellEdition = new SimpleTableCellEdition(elem, cellParams);

        // Storing DataTable index if table is DataTable
        if (this.isDataTable) {
            this.CellEdition.cellIndex = $(`#${this.tableId}`).DataTable().cell($(elem)).index();
        }

        // Extract old/current value from cell
        var oldVal = cellParams.internals.extractValue(elem);

        // flagging working cell
        $(elem).addClass(this.params.inEditClass);

        // Rendering 
        cellParams.internals.renderEditor(elem, oldVal);

        // Triggering edition mode entered event
        this._FireOnEditEnteredEvent(elem, oldVal);

    }

    _EndEditCell(elem, cellParams) {
        this._FreeCell(elem, cellParams, true);
    }

    _CancelEditCell(elem, cellParams) {
        this._FreeCell(elem, cellParams, false);
    }

    _FreeCell(elem, cellParams, keepChanges) {

        if (!this._isValidElem(elem) || this.CellEdition === null)
            return;

        // Triggering before exit event
        var onEditExitEvent = this._FireOnEditExitEvent(elem, this.CellEdition.oldValue);
        if (onEditExitEvent.isDefaultPrevented())
            return;

        // Get new val
        var newVal = cellParams.internals.extractEditorValue(elem);

        // clean cell
        $(elem).removeClass(this.params.inEditClass);
        $(elem).html('');

        // if validation method return false for new value AND value changed
        if (!cellParams.validation(newVal) || this.CellEdition.oldValue === newVal)
            keepChanges = false;

        // format new value
        var formattedNewVal = cellParams.formatter(newVal);

        // Trigger on edit exited event
        this._FireOnEditExitedEvent(elem, this.CellEdition.oldValue, formattedNewVal, keepChanges);

        if (keepChanges) {

            // render new value in cell
            cellParams.internals.renderValue(elem, formattedNewVal);

            // Trigger custom event
            this._FireEditedEvent(elem, this.CellEdition.oldValue, formattedNewVal);

        }
        else {

            // render old value
            $(elem).html(this.CellEdition.oldContent);

        }

        this.CellEdition = null;
    }

    _FreeCurrentCell(editionEndOrigin) {

        var current = this._GetCurrentEdition();

        if (current === null)
            return;

        var keepChanges = true;

        // If cell freeing comes from outside table click and cell params cause cancellation from outside table clicks
        if (editionEndOrigin === this.EditionEndOrigin.OutsideTable && current.cellParams.behaviour.outsideTableClickCauseCancellation)
            keepChanges = false; // We do not keep changes (cancellation)

        // If cell freeing comes from another cell click and cell params cause cancellation from another cells clicks
        if (editionEndOrigin === this.EditionEndOrigin.AnotherCell && current.cellParams.behaviour.anotherCellClickCauseCancellation)
            keepChanges = false; // We do not keep changes (cancellation)

        this._FreeCell(current.Elem, current.cellParams, keepChanges);


    }

    _GetCurrentEdition() {

        return (this.CellEdition === null ? null : this.CellEdition);
    }


    _GetExtendedEditorParams(_params) {

        var _instance = this;

        return $.extend(true, {}, _instance._GetDefaultEditorParams(), _params);

    }

    _GetExtendedCellParams(_cellParams) {

        var _instance = this;

        return $.extend(true, {}, _instance._GetDefaultCellParams(), _cellParams);

    }


    // Events
    _FireOnEditEnterEvent(elem) { // Before entering edit Mode

        var evt = jQuery.Event("cell:onEditEnter", { element: elem });

        $(`#${this.tableId}`).trigger(evt);

        return evt;
    }

    _FireOnEditEnteredEvent(elem, oldVal) { // After entering edit mode

        $(`#${this.tableId}`).trigger({
            type: "cell:onEditEntered",
            element: elem,
            oldValue: oldVal
        });
    }

    _FireOnEditExitEvent(elem, oldVal) { // Before exiting edit mode

        var evt = jQuery.Event("cell:onEditExit", { element: elem, oldValue: oldVal });

        $(`#${this.tableId}`).trigger(evt);

        return evt;
    }

    _FireOnEditExitedEvent(elem, oldVal, newVal, applied) { // After exiting edit mode

        $(`#${this.tableId}`).trigger({
            type: "cell:onEditExited",
            element: elem,
            newValue: newVal,
            oldValue: oldVal,
            applied: applied
        });
    }

    _FireEditedEvent(elem, oldVal, newVal) {

        $(`#${this.tableId}`).trigger({
            type: "cell:edited",
            element: elem,
            newValue: newVal,
            oldValue: oldVal
        });
    }


    // DataTable specific methods
    // _TryHandleDataTableReloadEvent() {

    //     var _instance = this;
    //     this.isDataTable = false;

    //     try {
    //         if ($.fn.DataTable.isDataTable(`#${_instance.tableId}`))
    //             _instance.isDataTable = true;
    //     } catch (e) {
    //         return;
    //     }

    //     if (_instance.isDataTable) {

    //         $(`#${_instance.tableId}`).on('draw.dt', function () {

    //             if (_instance.CellEdition !== null && _instance.CellEdition.Elem !== null) {

    //                 var node = $(`#${_instance.tableId}`).DataTable().cell(_instance.CellEdition.cellIndex).node();
    //                 _instance._EditCell(node, _instance.CellEdition.cellParams);

    //             }

    //         });

    //     }

    // }



    // Defaults
    _GetDefaultEditorParams() {

        return {
            inEditClass: "inEdit", // class used to flag cell in edit mode,
            navigation: true
        };
    }

    _GetDefaultCellParams() {

        return {
            validation: (value) => { return true; }, // method used to validate new value
            formatter: (value) => { return value; }, // Method used to format new value
            keys: {
                validation: [13],
                cancellation: [27]
            },
            behaviour: {
                tabKeyCauseCursorMove: true,    // Allow user to move through editable fields using tab key. Circular rotation
                arrowKeyCauseCursorMove: true,    // Allow user to move through editable fields using arrow key. Circular rotation
                outsideTableClickCauseCancellation: false,
                anotherCellClickCauseCancellation: false
            },
            internals: this._GetDefaultInternals()
        };

    }

    _GetDefaultInternals() {

        return {
            renderValue: (elem, formattedNewVal) => { $(elem).text(formattedNewVal); },
            renderEditor: (elem, oldVal) => {
                $(elem).offsetHeight
                $(elem).html(`<textarea type='text' style="width:100%; max-width:none">`);
                // Focus part
                var textarea = $(elem).find('textarea');
                textarea.focus();
                textarea.val(oldVal);
            },
            extractEditorValue: (elem) => { return $(elem).find('textarea').val(); },
            extractValue: (elem) => { return $(elem).text(); }
        };

    }



    // Utils
    _isValidElem(elem) {
        return (elem !== null && typeof elem !== 'undefined' && $(elem).length > 0);
    }

}