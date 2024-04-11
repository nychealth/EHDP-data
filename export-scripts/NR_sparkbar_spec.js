// ======================================================================= //
// setting up
// ======================================================================= //

// ----------------------------------------------------------------------- //
// lead required libraries
// ----------------------------------------------------------------------- //

const fs = require('fs');
const vl = require('vega-lite-api');

// ======================================================================= //
// construct spec
// ======================================================================= //

// ----------------------------------------------------------------------- //
// define chart with API
// ----------------------------------------------------------------------- //

const chart = vl

    // set mark type

    .markBar()

    // Define the named dataset

    .datasets({
        the_data: []
    })
    .data({name: "the_data"})

    // Set configuration options

    .config({
        axis: { grid: false },
        background: 'transparent',
        view: { continuousHeight: 300, continuousWidth: 300, strokeWidth: 0 }
    }) 

    // set encoding

    .encode(

        // Encode color

        vl.color().condition({
            test: "datum.neighborhood == 'Kingsbridge - Riverdale'",
            value: "#00923E"
        }).value("#D2D4CE"), 

        // Encode x-axis

        vl.x().axis(null).field('neighborhood').sort('y').type('nominal'),

        // Encode y-axis

        vl.y().axis(null).field('unmodified_data_value_geo_entity').type('quantitative')
    )
    
    // Set height

    .height(100) 

    // Set width

    .width(300); 


// ----------------------------------------------------------------------- //
// convert to spec
// ----------------------------------------------------------------------- //

const spec = JSON.stringify(chart.toSpec(), null, 4)


// ----------------------------------------------------------------------- //
// save spec as JSON
// ----------------------------------------------------------------------- //

// File path where JSON file will be saved

const filePath = 'neighborhood-reports/sparkbar_spec.json';


// Write JSON data to file

fs.writeFile(filePath, spec, (err) => {

  if (err) { console.error('Error writing JSON file:', err) }

});
