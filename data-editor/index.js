// ======================================================================= //
// setting up
// ======================================================================= //

// ----------------------------------------------------------------------- //
// lead required libraries
// ----------------------------------------------------------------------- //

const fs = require('fs');
const express = require('express');
const app = express();
const aq = require('arquero');
const bodyParser = require("body-parser");
const simpleGit = require("simple-git");
const { request } = require("@octokit/request")

console.log("__dirname", __dirname);

// ----------------------------------------------------------------------- //
// specify the base branch
// ----------------------------------------------------------------------- //

let base_branch = "feature-data-editor"

// ----------------------------------------------------------------------- //
// decide which database to use
// ----------------------------------------------------------------------- //

let dbValue;
const dbIndex = process.argv.indexOf('--database');

// Retrieve the value after --database 

if (dbIndex > -1) {

    dbValue = process.argv[dbIndex + 1];

} else if (process.argv.length > 2) {

    // if the flag doesn't exist, use the 3rd argument, if there is one

    dbValue = process.argv[2]

}

console.log("dbValue:", dbValue);

// default value is "old"

switch ((dbValue || "old")) {

  case "old":
    database = "BESP_IndicatorAnalysis";
    break;

  case "new":
    database = "BESP_EHDP_data";
    break;

}

console.log("database:", database);

// ----------------------------------------------------------------------- //
// set up git
// ----------------------------------------------------------------------- //

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// init simple git
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

let git = simpleGit({ 
    
    baseDir: __dirname,
    progress({ method, stage, progress }) {
        console.log(`git.${method} ${stage} stage ${progress}% complete`);
    }
    
})
.outputHandler((_command, stdout, stderr, args) => {
    console.log(_command, args)
    stderr.pipe(process.stderr);
});

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// set current branch name in button
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

let new_branch_name;

git.branch().then((msg) => {
    console.log("current_branch:", msg.current);
    new_branch_name = msg.current;
})


// ----------------------------------------------------------------------- //
// set express middleware
// ----------------------------------------------------------------------- //

// define parsers

app.use(bodyParser.json({ limit: '100mb' }));

// map folders to locations relative to host

app.use("/", express.static(`${__dirname}/public`));
// app.use("/", express.static(__dirname + '/public'));
app.use('/node_modules', express.static(`${__dirname}/node_modules`));
// app.use('/node_modules', express.static(__dirname + '/node_modules'));
app.use('/data', express.static(`${__dirname}/data`));
// app.use('/data', express.static(__dirname + '/data'));


// ======================================================================= //
// GET requests
// ======================================================================= //

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// send main HTML document (aka, load the page)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.get('/', (req, res) => {
    res.sendFile("index.html")
})

app.get('/database', (req, res) => {
    res.send(database)
})

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// send new branch name
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.get('/current_branch', (req, res) => res.send(new_branch_name))


// ======================================================================= //
// POST requests
// ======================================================================= //

// ----------------------------------------------------------------------- //
// define functions for routing requests
// ----------------------------------------------------------------------- //

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// function to create new branch
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

const new_branch = async (req, res) => {

    console.log("new_branch");

    // set datetime params for branch name

    const branch_time = new Date();
    const year = branch_time.getFullYear().toString().padStart(2, '0')
    const month = (branch_time.getMonth() + 1).toString().padStart(2, '0')
    const day = branch_time.getDate().toString().padStart(2, '0')
    const hour = branch_time.getHours().toString().padStart(2, '0')
    const minute = branch_time.getMinutes().toString().padStart(2, '0')
    const second = branch_time.getSeconds().toString().padStart(2, '0')
    
    // create branch name

    git.getConfig("user.name")
        .then(msg => msg.value)
        .then(user => {

            user = user.replaceAll(" ", "-")

            new_branch_name = `${year}${month}${day}_${hour}${minute}${second}_${user}_working-data-edits`

            console.log("new_branch_name:", new_branch_name);
            res.send({"new_branch_name": new_branch_name});
            
            // create new branch

            git.checkoutLocalBranch(new_branch_name)

        })
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// function to save incremental table edits
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

const edit = async (req, res) => {

    // create working dir if it doesn't exist

    fs.mkdir(`${__dirname}/data/working_edits/${database}/`, { recursive: true }, (err) => {

        if (err) {
            res.send({"ERROR [create 'working_edits/']": err})
            console.log("ERROR [create 'working_edits/']:", err)
            throw err;
        }
    })
    
    let params = req.params;
    let body = req.body;
    
    // save id column name and id values for edited rows
    
    let table_name = params.table_name
    let id_column = req.get("id_column")
    let id_values = req.get("id_values")

    // send back request params

    res.send({"params": params, "id_column": id_column, "id_values": id_values, "body": body })

    // add timestamp to table

    let timestamp = (new Date()).getTime()

    let aq_updated_data = aq.table(body)
        .derive({timestamp: `${timestamp}`})
    
    // turn updated data back into JSON

    let updated_data = aq_updated_data.toJSON({schema: false})

    // define file path

    let data_path_e = `${__dirname}/data/working_edits/${database}/${table_name}-${timestamp}.json`;

    console.log("data_path_e:", data_path_e);

    // write as stream, for performance reasons

    let writer = fs.createWriteStream(data_path_e) 
    
    writer.write(updated_data, (err, res) => {
        
        if (err) {
            console.log("ERROR [write edits]:", err)
            throw err;
        }
        // res.send({"ERROR [write edits]": err})

    });
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// function to compile table edits
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

const save = async (req, res) => {

    // timestamp for compiled edits

    let timestamp = (new Date()).getTime()
    
    // compile all edits to each table

    fs.readdir(`${__dirname}/data/working_edits/${database}/`, async (err, all_update_files) => {
        
        // remove .keep file from list
        let ki = all_update_files.indexOf(".keep")
        all_update_files.splice(ki, 1)

        console.log("-------------------------------------");
        console.log("all_update_files:", all_update_files);

        // parse edit file names into table names

        let table_names = [... new Set(all_update_files.map(n => n.replace(/(\w+)-\w*/, "$1").replace(".json", "")))]

        console.log("table_names:", table_names);


        // ==== iterate over table names ==================== //

        for await (nm of table_names) {

            let table_name = nm;
            
            console.log("table_name:", table_name);

            // regex to match table names

            const regex = new RegExp(`^${table_name}-`)

            // include files with this table name

            const table_files = all_update_files.filter(f => regex.test(f));

            console.log("table_files:", table_files);


            // ---- async load all files for each table type -------------------- //

            Promise.all(table_files.map(async file => {

                // Promise.all takes the array of promises returned by map, and then the `then` callback executes after they've all resolved

                // load JSON

                return aq.loadJSON(`${__dirname}/data/working_edits/${database}/${file}`).then(data => data.reify())

            }))


            // ---- process the data from tables of each type -------------------- //

            .then(async compiled_edits => {

                console.log("** compiled_edits");

                // concat the array into a single dataset

                let all_compiled_edits = await compiled_edits
                    .flatMap(d => d).reduce((a, b) => a.concat(b))
                    .orderby(aq.desc("timestamp"))

                // keep most recent revision

                let unique_compiled_edits = all_compiled_edits.dedupe(0)

                // set compiled data path

                let data_path_c = `${__dirname}/data/compiled_edits/${database}/${table_name}-${timestamp}.json`;

                // convert to JSON to save compiled

                let unique_compiled_edits_json = unique_compiled_edits.toJSON({schema: false})
                    
                // write compiled data

                fs.writeFile(data_path_c, unique_compiled_edits_json, (err) => {
                    if (err) {
                        res.send({"ERROR [write compiled]": err})
                        console.log("ERROR [write compiled]:", err)
                        throw err;
                    }

                })
                
                // also return, so that we can update that main data file

                return unique_compiled_edits;

            })


            // ---- update main data files with compiled edits -------------------- //

            .then(async compiled_edits => {

                console.log("** compiled_edits");

                // update main data file for this table

                let data_path_m = `${__dirname}/data/full_data/${database}/${table_name}.json`;

                fs.readFile(data_path_m, (err, data) => {

                    if (err) {
                        res.send({"ERROR [read main file]": err})
                        console.log("ERROR [read main file]:", err);
                        throw err;
                    } 

                    file_data = JSON.parse(data.toString());

                    // use first column as matching key

                    let id_col = Object.keys(file_data)[0]

                    // update only the edited row

                    let aq_table_data = aq.table(file_data)
                        .antijoin(compiled_edits, id_col)
                        .concat(compiled_edits)
                        .derive({ "sort_id": aq.escape( d => parseInt(d[id_col]))})
                        .orderby("sort_id")
                        .select(aq.not("sort_id"))

                    // turn updated data back into JSON

                    updated_data = aq_table_data.toJSON({schema: false})

                    // write main data table - this step isn't strictly necessary, but it means that input data for the table reflects edits

                    let writer = fs.createWriteStream(data_path_m) 

                    writer.write(updated_data, (err) => {

                        if (err) {
                            res.send({"ERROR [write main file]": err})
                            console.log("ERROR [write main file]:", err);
                            throw err;
                        } 

                    });

                })
            })

        }

    })
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// function to commit, push, PR changes
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

const commit = async (req, res) => {

    
    // ==== check branch and switch if necessary, then commit etc. ==================== //

    git.branch().then(async (msg) => {

        let to_send = [];

        console.log("msg.current:", msg.current);

        // ---- if base_branch, create a new branch -------------------- //

        if (msg.current == base_branch) new_branch(req, res);

        const commit_time = new Date();

        // ---- first add compiled edits and full data, then commit -------------------- //
        
        await git.add([`${__dirname}/data/compiled_edits/${database}/`, `${__dirname}/data/full_data/${database}/`])
            .commit(`data edits: ${commit_time.toDateString()} ${commit_time.toLocaleTimeString()}`)
            .push(['-u', 'origin', 'HEAD'], () => console.log('>>> pushed <<<'));
        
        // ---- then, create pull request using GitHub CLI -------------------- //

        // but only if one doesn't already exist for this branch

        await request('GET /repos/nychealth/EHDP-data/pulls', {
            owner: 'nychealth',
            repo: 'EHDP-data',
            headers: {
                'X-GitHub-Api-Version': '2022-11-28',
                authorization: "token " + process.env.token_for_everything
            }
        })
        .then(rslt => {

            // is there an open PR with the same title?

            let branch_pr = rslt.data.filter(pr => pr.title == new_branch_name && pr.state == "open")

            console.log("branch_pr:", branch_pr);

            // if not, open one

            if (branch_pr.length == 0) {

                console.log("rslt [PR GET]:", rslt);
                
                request('POST /repos/nychealth/EHDP-data/pulls', {
                    owner: 'nychealth',
                    repo: 'EHDP-data',
                    title: new_branch_name,
                    head: new_branch_name,
                    base: base_branch,
                    headers: {
                        'X-GitHub-Api-Version': '2022-11-28',
                        authorization: "token " + process.env.token_for_everything
                    }
                })

                // ---- send error to browser -------------------- //

                .catch(err => {
                    if (err) {
                        console.log("PR POST err", err);
                        to_send.push({"PR POST err": err})
                        throw err;
                    }
                })

                // ---- send result to browser -------------------- //

                .then(rslt => {
                    console.log("PR POST result:", rslt);
                    to_send.push({"PR POST result": rslt})
                    // res.send(to_send)
                })

            } else {
                res.send({"rslt [PR GET]": rslt})
            }

        })

    })

}

const unlink = () => {
    
    // ==== unlink files during commit ==================== //

    fs.readdir(`${__dirname}/data/working_edits/${database}/`, (err, all_update_files) => {
        
        // remove .keep file from list
        let ki = all_update_files.indexOf(".keep")
        all_update_files.splice(ki, 1)

        all_update_files.forEach(file => {

            fs.unlink(`${__dirname}/data/working_edits/${database}/${file}`, (err) => {
                console.log("unlink:", `data/working_edits/${file}`)
                if (err) {
                    console.log("unlink err:", err);
                    res.send({"unlink err": err})
                    throw err;
                }
            })
            
        });

    })
}


// ----------------------------------------------------------------------- //
// handle POST requests
// ----------------------------------------------------------------------- //

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// handle data edits POST
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.post('/post/:table_name', (req, res) => edit(req, res))

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// create a new branch on click
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.post('/new_branch', async (req, res) => {

    // first checkout base_branch branch

    await git.checkout(base_branch)

    // then pull any remote changes

    await git.pull('origin', base_branch)
    
    // finally, create new branch for edits

    new_branch(req, res);

})

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// handle commit POST
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.post('/commit', async (req, res) => {
    
    // first compile edits, then commit, etc.
    
    fs.readdir(`${__dirname}/data/working_edits/${database}/`, (err, files) => {
        
        // remove .keep file from list
        let ki = files.indexOf(".keep")
        files.splice(ki, 1)

        if (files.length > 0) {

            // if there are working edits, compile them, then commit

            save(req, res).then(() => commit(req, res))

        } else {

            // just commit compiled edits

            commit(req, res)

        }
    })
    
})

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
// stop Node process when exit button is clicked
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

app.post('/exit', async (req, res) => {

    // delete working edits
    unlink()

    // exit node process
    res.send("exit")
    process.exit()
    
})


// ======================================================================= //
// start server
// ======================================================================= //

const server = app.listen(8080);