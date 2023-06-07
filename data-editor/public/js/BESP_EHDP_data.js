// ##########################################################################
// ##########################################################################
// ##
// ## updating BESP_EHDP_data with edits
// ##
// ##########################################################################
// ##########################################################################

// UNDO BY KEEPING ARRAY OF ORIGINAL VERSION OF EDITED ROWS
// TOTAL UNDO BY GIT DISCARD

const show_BESP_EHDP_data = () => {

    console.log("show_BESP_EHDP_data");

    // ======================================================================= //
    // loading initial view on ready
    // ======================================================================= //

    $(function() {

        console.log("** load");

        table_name = location.hash.replace('#', "");

        if (!table_name) {

            table_name = "indicator"
            window.location.hash = table_name;

        } else {

            set_table_name(table_name)

            if (!["dataset", "visualization_dataset_flags", "new_viz"].includes(table_name)) {
            
                // console.log("normal [load]");

                let flex_btn_group = document.querySelector('#flex_btn_group')
                flex_btn_group.style.display = "none";

                load_data(table_name)

            } else {

                // console.log("flags [load]");

                let flex_btn_group = document.querySelector('#flex_btn_group')
                flex_btn_group.style.display = "";

                load_flexdatalist(table_name)

            }

        }

    })


    // ======================================================================= //
    // setting up
    // ======================================================================= //

    // ----------------------------------------------------------------------- //
    // create global variables
    // ----------------------------------------------------------------------- //

    // let data_table;
    let table_name;
    let edited_id;
    let edited_row_clones = []; // persists until commit
    let visualization_id = 0; // persists until commit
    let selected_visualization_type_id;
    let shiftKey;
    let last_indexes;

    const edited_rows = new Object();
    const edited_cells = new Object();


    // listing table names

    let table_names = [
        "data_flag",
        "geography_type",
        "geography",
        "indicator",
        "measure",
        "measurement_type",
        "source_measure",
        "source",
        "time_period",
        "unit",
        "dataset",
        "visualization_dataset_flags",
        "new_viz"
    ]

    // console.log("table_names", table_names);

    // ----------------------------------------------------------------------- //
    // housekeeping
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // nulling things to make toggle work
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    document.querySelector('#table').innerHTML = "";
    document.querySelector('#table_names').innerHTML = "";

    $(window).off("load")
    $(window).off("hashchange")

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // load current branch name
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    fetch("current_branch")
        .then(response => response.text())
        .then(data => document.querySelector("#branch > pre").innerText = data)


    // ======================================================================= //
    // table and interactions
    // ======================================================================= //

    // ----------------------------------------------------------------------- //
    // handling edits
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // creating custom edit event
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    let edit_event = new Event("edit_event")

    // ----------------------------------------------------------------------- //
    // setting dropdowns
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // table_name dropdown items
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    let tabnames = document.querySelector('#table_names')

    for (tab = 0; tab < table_names.length; tab++) {

        let nm = table_names[tab];
        let nm_li = document.createElement('li')
        let nm_li_a = document.createElement('a')

        nm_li_a.id = nm;
        nm_li_a.href = "#" + nm
        nm_li_a.classList.add("dropdown-item", "text-primary", "table_name_item");

        $(nm_li_a).css("font-family", "monospace")

        nm_li_a.innerText = nm

        nm_li.appendChild(nm_li_a)
        tabnames.appendChild(nm_li)

    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // viz type dropdown items
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    let viz_type_names = document.querySelector('#viz_type_names')

    // fetch data

    fetch(`data/full_data/BESP_EHDP_data/visualization_type.json`)
        .then(response => response.json())
        .then(data => {

            let vt_names = data.description;
            let vt_ids   = data.visualization_type_id;

            // console.log("vt_names", vt_names);
            
            // loop thru names

            for (vt = 0; vt < vt_names.length; vt++) {

                let vtn = vt_names[vt];
                let vtn_btn = document.createElement('button');

                // construct items

                vtn_btn.id = vtn + "-" + vt_ids[vt];
                vtn_btn.classList.add("dropdown-item", "text-primary", "viz_type_item");
                vtn_btn.innerText = vtn;
                
                // set font style

                $(vtn_btn).css("font-family", "monospace")
                
                // set data attr

                $(vtn_btn).attr("data-visualization_type_id", vt_ids[vt])

                // append to dropdown

                viz_type_names.appendChild(vtn_btn);

            }

            // set initial viz type name in button

            $('#viz_type_button').text(vt_names[0])

            // save initial viz type id

            selected_visualization_type_id = vt_ids[0]

            // show first viz type as active

            $("#viz_type_item div").removeClass("active")
            $(`#${vt_names[0]}-${selected_visualization_type_id}`).addClass("active")

    })


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // switch viz type on item click
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    $("#viz_type_names").on("click", e => {

        // save selected visualization_type_id

        selected_visualization_type_id = e.target.dataset.visualization_type_id;

        console.log("selected_visualization_type_id [click]", selected_visualization_type_id);
        
        // if viz type is changed, deselect all selected cells

        data_table.cells('.has-checkbox.selected').deselect();

        // set button text

        let viz_type_name = e.target.innerText;
        $('#viz_type_button').text(viz_type_name)

        // set newly clicked item as active

        $("#viz_type_names > button").removeClass("active")
        $(`#${viz_type_name}-${selected_visualization_type_id}`).addClass("active")

        if (data_table) {

            let vt_cells = data_table.cells("", ":contains(visualization_type_id)")

            vt_cells.nodes().each(el => el.innerText = selected_visualization_type_id)
            vt_cells.invalidate()

        }

    })


    // ----------------------------------------------------------------------- //
    // function to set table name in some elements
    // ----------------------------------------------------------------------- //

    const set_table_name = (table_name) => {

        console.log("** set_table_name");

        if (!table_name) table_name = "indicator"

        window.location.hash = table_name;

        // set table name in button

        let table_button = document.querySelector('#table_button')
        table_button.innerHTML = "<span><b><pre>" + table_name + "</pre></b></span>"
        
        // set table name in the search box

        $('.flexdatalist').attr("placeholder", "Search indicators or measures")

        $("#table_names li a").removeClass("active")
        $(`#${table_name}`).addClass("active")

        // show or hide viz type button

        if (table_name == "new_viz") {

            // show viz type dropdown

            let viz_type_button = document.querySelector('#viz_type_button')
            viz_type_button.style.display = "";

        } else {

            let viz_type_button = document.querySelector('#viz_type_button')
            viz_type_button.style.display = "none";

        }

    }


    // ----------------------------------------------------------------------- //
    // function for listening to table change
    // ----------------------------------------------------------------------- //

    $(window).on("hashchange", (e) => {

        console.log("** hashchange");

        table_name = e.target.location.hash.replace('#', "");

        if (!table_name) {

            set_table_name()
            table_name = e.target.location.hash.replace('#', "");

        } else {

            set_table_name(table_name)

            if (!["dataset", "visualization_dataset_flags", "new_viz"].includes(table_name)) {
            
                // console.log("normal [hashchange]");

                let flex_btn_group = document.querySelector('#flex_btn_group')
                flex_btn_group.style.display = "none";

                load_data(table_name)

            } else {

                // console.log("flags [hashchange]");

                let flex_btn_group = document.querySelector('#flex_btn_group')
                flex_btn_group.style.display = "";

                load_flexdatalist(table_name)

            }

        }

    })


    // ----------------------------------------------------------------------- //
    // construct flexdatalist for viz tbales
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // search helper function
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    const stringNorm = (string) => {
            let newString = string
                .replace(/[.,\[\]\/#!$%\^&\*;:{}=\-_`~()]/g, " ")
                .trim()
                .replace(/\s{2,}/g, " ")

            return newString;
        }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // function to load flexdatalist
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    const load_flexdatalist = async (table_name) => {

        console.log("** load_flexdatalist");

        // get 2 lists of inidcator names

        let indicator_measure_names_concat;
        let indicator_measure_names;

        await Promise.all([

            // for display

            fetch(`data/full_data/BESP_EHDP_data/indicator_measure_names_concat.json`)
                .then(response => response.json())
                .then(data => {
                    indicator_measure_names_concat = data;
            }),
            
            // for joining

            fetch(`data/full_data/BESP_EHDP_data/indicator_measure_names.json`)
                .then(response => response.json())
                .then(data => {
                    indicator_measure_names = data
            })

        ])
        
        // init flexdatalist

        let $input = $('.flexdatalist').flexdatalist({
            minLength: 0,
            valueProperty: ["indicator_id", "measure_id"],
            textProperty: "{indicator_id} {Indicator}",
            selectionRequired: false,
            focusFirstResult: true,
            visibleProperties: ["indicator_id", "Indicator", "measure_id", "Measure"],
            searchIn: ["indicator_id", "measure_id", "Indicator", "Measure"],
            searchContain: true,
            searchByWord: true,
            redoSearchOnFocus: true,
            normalizeString: stringNorm,
            cache: false,
            data: ["dataset", "visualization_dataset_flags"].includes(table_name) ? indicator_measure_names_concat : aq.table(indicator_measure_names).objects()
        });

        document.getElementById('table').innerHTML = ""

        // console.log("$input [load_flexdatalist]:", $input);
            
        $input.on('select:flexdatalist', (e, set) => {

            console.log(">> select:flexdatalist");

            // console.log("set", set);

            let indicator_id = set.indicator_id
            let measure_id   = set.measure_id

            // console.log("indicator_id", indicator_id);

            // filter the datatable

            if (["dataset", "visualization_dataset_flags"].includes(table_name)) {

                load_viz_flags(table_name, indicator_id)

            } else if (table_name == "new_viz") {

                load_new_viz(table_name, measure_id)

            }

        })


        // add clear button handler here to get table_name

        $("#clear").on("click", () => {

            // console.log("table_name [clear]", table_name);

            console.log(">> clear flexdatalist");

            $("#flex_search-flexdatalist").val("")

            // if this is the new viz table, re-add the edited rows to the table after clear
            //  these are clones, so some of the rows will be duplicated. if they're both edited, the most recent edit wins.

            if (table_name == "new_viz") {

                data_table.clear();

                // console.log("edited_row_clones [clear]", edited_row_clones);

                // edited_row_clones persists until commit

                edited_row_clones.forEach(ed => data_table.row.add(ed))

                // also order by the "include" flag
                
                data_table.order( [data_table.columns().count() - 1, 'desc'] ).draw("page");

            } else {

                data_table.clear().draw("page")

            }

        })

    }


    // ----------------------------------------------------------------------- //
    // data loading
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // regular tables
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    const load_data = (table_name) => {

        console.log("** load_data");

        fetch(`data/full_data/BESP_EHDP_data/${table_name}.json`)
            .then(response => response.json())
            .then(async (data) => {

                // input is set of named columns

                let aq_table_data = await aq.table(data)
                
                // console.log("aq_table_data [load_data]");
                // aq_table_data.print(10)

                make_table(aq_table_data, table_name)

                $("#tableID").DataTable()
                    .columns()
                    .every(function(i) { 

                        if (i != 0) {

                            let col = this;

                            // make column editable

                            $(col.nodes()).addClass("editable") 

                            // set editable header color

                            $(col.header()).css("background-color", "#D3FEF3")

                        }
                        
                    })
                    .draw("page")
                
            })

    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // visualization flags and dataset flags
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    const load_viz_flags = (table_name, indicator_id) => {

        console.log("** load_viz_flags");

        fetch(`data/full_data/BESP_EHDP_data/${table_name}.json`)
            .then(response => response.json())
            .then(async (data) => {

                let aq_geography_type;
                let aq_time_period;

                // console.log("data [load_viz_flags]", data);

                // get other tables to join, and wait for them

                await Promise.all([

                    fetch(`data/full_data/BESP_EHDP_data/indicator_measure_names.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_indicator_measure_names = aq.table(data)
                    }),

                    fetch(`data/full_data/BESP_EHDP_data/geography_type.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_geography_type = aq.table(data)
                                .select("geography_type_id", "name")
                                .rename({"name": "geography_type"})
                    }),

                    fetch(`data/full_data/BESP_EHDP_data/time_period.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_time_period = aq.table(data)
                                .select("time_period_id", "description")
                                .rename({"description": "time_period"})
                    }),

                ])


                // input is set of named columns

                let aq_table_data = await aq.table(data)
                    .join_left(aq_indicator_measure_names, "measure_id")
                    .filter(`d => d.indicator_id == ${indicator_id}`)
                    .join_left(aq_geography_type, "geography_type_id")
                    .join_left(aq_time_period, "time_period_id")
                    .relocate(
                        [
                            "indicator_id", 
                            "Indicator", 
                            "measure_id", 
                            "Measure",
                            "geography_type_id",
                            "geography_type",
                            "time_period_id",
                            "time_period"
                        ], 
                        {after: 1}
                    )
                    .reify()
                
                // console.log("aq_table_data [load_viz_flags]");
                // aq_table_data.print(10)

                // draw the table

                make_table(aq_table_data, table_name)

                // make "publish" column editable (and maybe a dropdown later) - only in `dataset`

                $("#tableID").DataTable().column(":contains(publish)")
                    .every(function() { 

                        let col = this;

                        // make column editable

                        $(col.nodes()).addClass("editable") 

                        // set editable header color

                        $(col.header()).css("background-color", "#D3FEF3")
                        
                    })

                // make `visualization_dataset_flags` flag columns checkboxes

                data_table
                    .columns(
                        `:contains(tbl), :contains(map), :contains(trend), 
                        :contains(links), :contains(disp), :contains(nr)`,
                        {page:'all'}
                    )
                    .every( function () { 

                        // "this" is the dt.column()

                        let col = this;

                        console.log("col", col);
                        
                        let col_nodes = $(col.nodes());

                        $(col.header()).css("background-color", "#D3FEF3")

                        // console.log("col_nodes", col_nodes)

                        col_nodes.each(

                            function(i, el) { 

                                // nodes.push(i)

                                if ($(el).text() == "NA") {

                                    $(el).prop( "disabled", true )
                                    $(el).css( "color", "gray" )
                                    $(el).addClass("has-checkbox")

                                } else {

                                    // console.log(i)

                                    $(el).addClass("has-checkbox")


                                }

                            }
                        )

                    })
                    .draw("page")
                
            })

    }


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // new vizualization builder
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    // starts with dataset - that's the canonical source, like subtopic_indicators, 
    //  appended when the data are added

    const load_new_viz = (table_name, measure_id) => {

        console.log("** load_new_viz");

        // set viz type name in button

        // $(".viz_type_item")[0].innerText
        // $('#viz_type_button').text($(".viz_type_item")[0].innerText)

        // save default viz type id (table)

        console.log("selected_visualization_type_id [load_new_viz]", selected_visualization_type_id);

        if (typeof selected_visualization_type_id == "undefined") {

            console.log("@@@ undefined");

            selected_visualization_type_id = $(".viz_type_item")[0].dataset.visualization_type_id

        }

        // set temporary PK for visualization table

        if (visualization_id == 0) {

            visualization_id = (new Date()).getTime()

        }

        // console.log("visualization_id [load_new_viz]", visualization_id);

        fetch(`data/full_data/BESP_EHDP_data/dataset.json`)
            .then(response => response.json())
            .then(async (data) => {

                let aq_indicator_measure_names;
                let aq_geography_type;
                let aq_time_period;

                // console.log("data [load_new_viz]", data);

                // get other tables to join, and wait for them

                await Promise.all([

                    fetch(`data/full_data/BESP_EHDP_data/indicator_measure_names.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_indicator_measure_names = aq.table(data)
                    }),

                    fetch(`data/full_data/BESP_EHDP_data/geography_type.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_geography_type = aq.table(data)
                                .select("geography_type_id", "name")
                                .rename({"name": "geography_type"})
                    }),

                    fetch(`data/full_data/BESP_EHDP_data/time_period.json`)
                        .then(response => response.json())
                        .then(data => {
                            aq_time_period = aq.table(data)
                                .select("time_period_id", "description")
                                .rename({"description": "time_period"})
                    }),

                    fetch(`data/full_data/BESP_EHDP_data/visualization_type.json`)
                        .then(response => response.json())
                        .then(data => {
                            visualization_type = data
                    }),

                ])


                // input is set of named columns

                let aq_table_data = await aq.table(data)
                    .join_left(aq_indicator_measure_names, "measure_id")
                    // .print()
                    .filter(`d => d.measure_id == ${measure_id}`)
                    .join_left(aq_geography_type, "geography_type_id")
                    .join_left(aq_time_period, "time_period_id")
                    .relocate(
                        [
                            "indicator_id", 
                            "Indicator", 
                            "measure_id", 
                            "Measure",
                            "geography_type_id",
                            "geography_type",
                            "time_period_id",
                            "time_period"
                        ], 
                        {after: 1}
                    )
                    .derive({
                        "visualization_id": `${visualization_id}`,
                        "visualization_type_id": `${selected_visualization_type_id}`,
                        "include": "0"
                    })
                    .reify()
                
                // console.log("aq_table_data [load_viz_flags]");
                // aq_table_data.print(10)

                make_table(aq_table_data, table_name)

                // console.log("edited_row_clones [load_new_viz]", edited_row_clones);

                edited_row_clones.forEach(ed => data_table.row.add(ed));

                data_table
                    .columns(':contains(include)', {page:'all'})
                    .every( function () { 
                        
                        // "this" is the dt.column()

                        let col = this;

                        console.log("col", col);
                        
                        let col_nodes = $(col.nodes());
                        // let nodes = []
                        // let has_checkbox = []
                        // let is_checked = []

                        $(col.header()).css("background-color", "#D3FEF3")

                        // console.log("col_nodes", col_nodes)

                        col_nodes.each(

                            function(i, el) { 

                                // nodes.push(i)

                                if ($(el).text() == "NA") {

                                    $(el).prop( "disabled", true )
                                    $(el).css( "color", "gray" )
                                    $(el).addClass("has-checkbox")

                                } else {

                                    // $(el).addClass("has-checkbox").append('<label class="container"><input type="checkbox" /><span class="checkmark"></span></label>')
                                    $(el).addClass("has-checkbox")
                                    // $(el).addClass("has-checkbox").css("background-color", "red")

                                    // check boxes with 1

                                    // $(".has-checkbox").each((i, chk) => { 

                                    //     if (chk.innerText == "1") {

                                    //         $(chk).find("input[type=checkbox]").prop("checked", true)

                                    //     } else {

                                    //         $(chk).find("input[type=checkbox]").prop("checked", false)

                                    //     }

                                    // })

                                }

                            }
                        )

                    })

                data_table
                    .columns(':contains(visualization_id), :contains(visualization_type_id)')
                    .visible(false)

                data_table.order( [data_table.columns().count() - 1, 'desc'] ).draw("page")
                
            })

    }

    // ----------------------------------------------------------------------- //
    // construct editable DataTable
    // ----------------------------------------------------------------------- //

    const make_table = (data, table_name) => {

        console.log("** make_table");
        // console.log("table_name [make_table]", table_name);

        // console.log("data [make_table]");
        // data.print()

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // set editable params for this table
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        let ncols = data.numCols()
        let editable = Array(ncols-1).fill(1).map( (_, i) => i+1 )
        let col_names = data.columnNames()

        // console.log("col_names", col_names);

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // export Arquero table to HTML
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        document.getElementById('table').innerHTML = 
            data.toHTML({
                limit: Infinity
            });

        // this gives the table an ID (table code generated by Arquero)
        
        document.querySelector('#table table').id = "tableID"
        
        // set some display properties 
        
        document.querySelector('#tableID').className = "table table-hover table-striped table-bordered"
        document.querySelector('#tableID').width = "100%"

        let table2 = document.querySelector('#tableID');

        // Create an empty <tfoot> element and add it to the table:

        var footer = table2.createTFoot();

        footer.innerHTNL = document.querySelector('#tableID thead').innerHTML


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // add additional DataTable header with search fields
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        $('#tableID thead tr')
            .addClass("headings table-secondary")
            .before(
                $('#tableID thead tr')
                .clone()
                .addClass("filters table-secondary")
                .removeClass("headings")
            )

        $('#tableID .filters th').each( function () {

            let title = $('#tableID thead .filters th').eq($(this).index()).text();

            $(this).html('<input style="display: inline; width: 100%" type="text" placeholder="' + title + '"></input>')

        });


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // initialize DataTable
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        // ordering specs for new_viz

        let include = $.fn.dataTable.absoluteOrder([
            { value: 1, position: 'top'}
        ]);

        let new_viz_columnDefs = [{
            targets: -1,
            type: include
        }]


        // ==== init ====================== //

        data_table = $('#tableID').DataTable({
            dom: "<'d-flex row pb-1 px-3'" + 
                    "<'d-flex col-sm-8'i>" +
                    "<'d-flex col-sm-4 justify-content-end'<'pt-1 px-3'l>p>>" + 
                    "<'row mx-0'<'col-sm-12'tr>>",
            scrollX: true,
            scrollCollapse: true,
            autoWidth: true,
            paging: true,
            bInfo: true,
            select: {
                style:    'multi+shift',
                selector: '.has-checkbox',
                items: "cell"
            },
            // select: (["visualization_dataset_flags", "new_viz"].includes(table_name)) ? true : false,
            fixedHeader: {
                header: true
            },
            columnDefs: table_name == "new_viz" ? new_viz_columnDefs : {},
            lengthMenu: [ 5, 10, 20, 50, 100 ],
            pageLength: 20,
            initComplete: function () {

                // adjust the sizes of the columns

                this.api().columns.adjust().draw("page")

                // add column search interaction

                this.api().columns().eq(0).each(function (search_col) {

                    let that = this;

                    $('input', $('.filters th')[search_col]).on('keyup change clear', function (x) {

                        search_term = this.value;

                        if (that.column(search_col).search() !== this.value) {
                            
                            that.column(search_col).search(this.value, false, false, true).draw("page");
                        }
                        
                    });
                })

            }
        })

        // table click handler

        data_table.on("click", e => {

            shiftKey = e.shiftKey;

            // stop the click from triggering the "select" event (because it also triggers "deselect")

            e.preventDefault()

        })


        // DT selection handler

        data_table.on( 'select', function ( e, dt, type, indexes ) {

            // console.log("indexes [select]", indexes);
            // console.log("last_indexes [select]", last_indexes);

            if (["dataset", "visualization_dataset_flags", "new_viz"].includes(table_name)) {

                // console.log("e [select]", e);
                
                // iterate over the selected row(s)
                
                for (const idx of indexes) {

                    let row = idx.row;
                    let column = idx.column;

                    // console.log("row", row, "column", column);
                    
                    // $(data_table.rows(row).nodes()).addClass("bg-warning-subtle")
                    // $(data_table.row(idx.row).node()).addClass("bg-warning-subtle")

                    // if the shift key is pressed, then don't modify the already-selected row in
                    //  the range selection

                    if (shiftKey && typeof last_indexes != "undefined" && last_indexes.map(i => JSON.stringify(i)).some(o => o == JSON.stringify(idx))) {

                        // do nothing to the row

                    } else {

                        // if the shift key isn't pressed or there's no overlapping indexes,
                        //  modify the row

                        // get text
                        
                        let cell_text = $(data_table.cell(idx).node()).text()
                        let new_cell_text = (cell_text == "0" ? "1" : "0")

                        // console.log("cell_text", cell_text);
                        // console.log("new_cell_text", new_cell_text);

                        // set cell text

                        let text_content = data_table.cell(idx).node()?.childNodes[0].textContent

                        if (text_content) {

                            console.log("text_content", text_content);

                            data_table.cell(idx).node().childNodes[0].textContent = new_cell_text

                        }
                        
                        // switch check

                        // let this_checkbox = $(data_table.cell(idx).node()).find("input[type=checkbox]")
                        // let is_checked = this_checkbox.prop("checked")

                        // this_checkbox.prop("checked", is_checked ? false : true)
                        
                        // wait half a second before telling DT about the change and triggering sort
                        
                        setTimeout(() => {
                            
                            // tell DT to refresh the data for this cell
                            
                            // data_table.cell(idx).invalidate()
                            
                            // save table edits
                            
                            save_edits(idx.row, idx.column)
                            
                        }, 100)
                        
                    }
                    
                }
                
                // save these indexes

                last_indexes = indexes;

            }

            e.stopPropagation()

        });


        // DT deselection handler

        data_table.on( 'deselect', function ( e, dt, type, indexes ) {

            // console.log("indexes [deselect]", indexes);
            // console.log("last_indexes [deselect]", last_indexes);

            if (["dataset", "visualization_dataset_flags", "new_viz"].includes(table_name)) {

                // console.log("e [deselect]", e);
                
                let row = indexes[0].row;
                let column = indexes[0].column;

                // iterate over the selected row(s)

                for (const idx of indexes) {

                    let row = idx.row;
                    let column = idx.column;

                    // console.log("row", row, "column", column);
                    
                    // $(data_table.rows(row).nodes()).addClass("bg-warning-subtle")
                    // $(data_table.row(idx.row).node()).removeClass("bg-warning-subtle")

                    // if the shift key is pressed, then don't modify the already-selected row in
                    //  the range selection

                    if (shiftKey && typeof last_indexes != "undefined" && last_indexes.map(i => JSON.stringify(i)).some(o => o == JSON.stringify(idx))) {

                        // do nothing to the row

                    } else {

                        // if the shift key isn't pressed or there's no overlapping indexes,
                        //  modify the row

                        // get text
                        
                        let cell_text = $(data_table.cell(idx).node()).text()
                        let new_cell_text = (cell_text == "0" ? "1" : "0")

                        // set cell text

                        let text_content = data_table.cell(idx).node()?.childNodes[0].textContent

                        if (text_content) {

                            console.log("text_content", text_content);

                            data_table.cell(idx).node().childNodes[0].textContent = new_cell_text

                        }
                        
                        // switch check

                        // let this_checkbox = $(data_table.cell(idx).node()).find("input[type=checkbox]")
                        // let is_checked = this_checkbox.prop("checked")

                        // this_checkbox.prop("checked", is_checked ? false : true)
                        
                        // wait half a second before telling DT about the change and triggering sort
                        
                        setTimeout(() => {
                            
                            // tell DT to refresh the data for this cell
                            
                            data_table.cell(idx).invalidate()
                            
                            // save table edits
                            
                            save_edits(idx.row)
                            
                        }, 100)
                        
                    }
                }

                if (table_name == "new_viz") {

                    data_table.order( [data_table.columns().count() - 1, 'desc' ], [0, "asc"] ).draw("page")

                }
                
                // save these indexes
                
                last_indexes = indexes;

            }

            e.stopPropagation()

        });


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // make table editable
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        // initialize SimpleTableCellEditor

        simple_editor_table = new SimpleTableCellEditor("tableID");
        simple_editor_table.SetEditableClass("editable");

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // handle cell editor events, which we also use to resize the textarea window
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        // data edits

        data_table.on("cell:edited", e => {

            console.log("e [cell:edited]", e);

            save_edits(e.element._DT_CellIndex.row, e.element._DT_CellIndex.column)

        })

        // resizing

        let rowheight;

        data_table.on("cell:onEditEnter", event => {

            console.log("cell:onEditEnter");

            rowheight = $(event.element).height()

        })

        data_table.on("cell:onEditEntered", event => {

            $(event.element).css("padding", "2px")
            $(event.element).find("textarea").height(rowheight)
            $(event.element).find("textarea").css("padding", "2px")
            $(event.element).find("textarea").css("font-size", "0.95em")

        })

        data_table.on("cell:onEditExited", event => {

            $(event.element).height("100%")
            $(event.element).css("padding", "8px")

        })


        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
        // handle cell content change
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

        const save_edits = async (row, column) => {

            console.log("edited_rows [save_edits]", edited_rows);

            // console.log(">> edited");
            console.log("row [edit]", row);


            // ==== un-highlight rows & cells whose changes have been undone ====================== //

            // save original cell data

            let original_cell_data = data_table.cell(row, column).data()

            // save original row data

            let original_row_data_json = JSON.stringify(data_table.row(row).data())

            // tell DT to refresh the data for this row

            data_table.row(row).invalidate()

            // this is data before the edits have been applied to the DT, which happens on DT.invalidate()

            let cell_data = data_table.cell(row, column).data()
            let row_data = data_table.row(row).data()
            let row_id = row_data[0]
            let row_data_json = JSON.stringify(row_data)
            let edited_ids = Object.keys(edited_rows)

            // console.log("row_data [save_edits]", row_data);
            console.log("row_data_json:", row_data_json);
            console.log("cell_data:", cell_data);


            // ---- check cell edit status ---------------------- //

            console.log(">> cell index", `${row},${column}`);
            console.log(">> cell 1", edited_cells[`${row},${column}`]);
            console.log(">> cell 2", cell_data);

            if (edited_cells[`${row},${column}`]) {

                console.log("edited cell");

                // remove background color on edited cell if it's identical to original

                if (edited_cells[`${row},${column}`] == cell_data) {

                    console.log("cells equal");
                    
                    $(data_table.cell(row, column).node()).css("background-color", "")

                } else {

                    $(data_table.cell(row, column).node()).css("background-color", "#FCE7ED")

                }

            } else {

                console.log("new cell");

                edited_cells[`${row},${column}`] = original_cell_data;

            }


            // ---- check row edit status ---------------------- //

            if (edited_ids.includes(row_id)) {

                console.log("++ already edited");

                // if this row was already edited, check to see if the edited row is identical to the original version

                console.log("edited_rows[row_id]:", edited_rows[row_id]);

                if (edited_rows[row_id] == row_data_json) {

                    console.log("+++ identical");

                    // remove background color on edited row

                    $(data_table.row(row).node()).removeClass("table-warning")

                    // remove background color for each cell

                    $(data_table.row(row).nodes()).find("td").each((i, td) => $(td).css("background-color", ""))

                } else {

                    console.log("+++ different");

                    // set background color on edited row

                    $(data_table.row(row).node()).addClass("table-warning")

                    // set background color on edited cell

                    // $(data_table.cell(row, column).node()).css("background-color", "#FCE7ED")

                }

            } else {

                console.log("++ not edited yet");
                console.log("original_row_data_json:", original_row_data_json);

                // if this hasn't been edited yet, add an entry to the object

                edited_rows[row_id] = original_row_data_json;

                // set background color on edited row

                $(data_table.row(row).node()).addClass("table-warning")

                // set background color on edited cell

                $(data_table.cell(row, column).node()).css("background-color", "#FCE7ED")

            }
            
            // // tell DT to refresh the data for this row

            // data_table.row(row).invalidate()

            // trigger draw

            data_table.draw("page")

            // if new viz, save edited row

            if (table_name == "new_viz") {

                edited_row_clones.push($(data_table.row(row).node()).clone())

                // console.log("edited_row_clones [edit]", edited_row_clones);

                data_table.order( [data_table.columns().count() - 1, 'desc'] ).draw()

            }


            // ==== export table data to JSON ====================== //

            let table_data = data_table.columns().data().toArray()

            // console.log("table_data", table_data);

            // turn array of arrays into object of named columns

            let table_data_obj = {}

            table_data.forEach((el, i) => {

                table_data_obj[col_names[i]] = el;

            })

            // turn into arquero table

            let aq_table_data = aq.table(table_data_obj)

            // console.log("aq_table_data");
            // aq_table_data.print()

            // ==== filter local table based on edited id ====================== //

            edited_id = data_table.cell(row, 0).data();

            let jsonNamedColumns = aq_table_data
                .filter(aq.escape(d => d[col_names[0]] == edited_id))
                .select(aq.all(col_names))
                .toJSON({schema: false})
                .replace( /(<([^>]+)>)/ig, '')

            // ==== post updated data to server ====================== //

            $.ajax({
                type: "POST",
                url: "http://localhost:8080/post/" + table_name,
                data: jsonNamedColumns,
                headers: {"id_column": col_names[0], "id_values": edited_id},
                contentType : "application/json",
                success: function (result) {
                },
                error: function (request, status, error) {
                    alert("ERROR [edit]:\n" + error)
                    console.log(["ERROR [edit]:", {"request:": request, "status:": status, "error:": error}]);
                }
            });

        };

    }


    // ----------------------------------------------------------------------- //
    // other POST endpoints for saving data
    // ----------------------------------------------------------------------- //

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // compile and commit changes
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    $("#commit").on("click", event => {
        
        console.log(">> commit");

        // reset edited_row_clones, use by new_viz

        edited_row_clones = []

        // reset visualization_id

        visualization_id = 0;

        $.ajax({
            type: "POST",
            url: "http://localhost:8080/commit",
            contentType : "application/json",
            success: function (result) {
                alert("Commit success!\n=) =)")
                console.log("commit result:", result);
            },
            error: function (request, status, error) {
                alert("Commit error!\n=( =(\n\n" + "Check console")
                console.log(["ERROR [commit]:", {"request:": request, "status:": status, "error:": error}]);
            }
        });
    })


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // create new branch
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    $("#new_branch").on("click", event => {

        console.log(">> new_branch");

        $.ajax({
            type: "POST",
            url: "http://localhost:8080/new_branch",
            contentType : "application/json",
            success: function (result) {
                console.log("new_branch", result);
                document.querySelector("#branch > pre").innerText = result.new_branch_name
            },
            error: function (request, status, error) {
                console.log(["ERROR [new_branch]:", {"request:": request, "status:": status, "error:": error}]);
            }
        });
    })


    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // exit Node.js process
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

    $("#exit").on("click", event => {
        
        console.log(">> exit");

        $.ajax({
            type: "POST",
            url: "http://localhost:8080/exit",
            contentType : "application/json",
            success: function (result) {
                console.log("exit result:", result);
            },
            error: function (request, status, error) {
                console.log(["ERROR [exit]:", {"request:": request, "status:": status, "error:": error}]);
            }
        });
    })

}