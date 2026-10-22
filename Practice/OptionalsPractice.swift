//
//  OptionalsPractice.swift
//  Salman's Swift practice (structs, optionals, guard). NOT part of the app.
//
//  WHY it lives here: files inside `Alarm/` are compiled into the app, and an app file
//  may only contain declarations (struct, class, func, let…). Statements like `guard`
//  and `print(...)` at the top level are only allowed in a *script*, which is what this is.
//  (This code was moved here unchanged from the bottom of AlarmListViewModel.swift,
//  where it stopped the app from building.)
//
//  RUN IT in Terminal from the project folder:
//      swift Practice/OptionalsPractice.swift
//
//  EXERCISE: the first run shows an error. Fix these two things yourself:
//    1. `return` is only valid inside a function. At the top level of a script,
//       leave a `guard` with `exit(0)` (add `import Foundation` at the top), or wrap
//       the code in a function and call it.
//    2. In the print, `"/(PERSON1: ...` uses a forward slash. String interpolation
//       needs a backslash: `\(...)`.
//



struct Person {
    
    let man: Man?
    let woman: Woman?
    
    init(man: Man?, woman: Woman?) {
        self.man = man
        self.woman = woman
    }
    
}

struct Man {
    
    let name : String?
    
    
}

struct Woman {
    
    let name : String?
    
}

let mann = Man(name: "salman")
let womann = Woman (name: "Hazel")

let person1 = Person(man: mann, woman: womann)
//let person: Person? = nil

//print(womann)

guard let woman = person1.woman else {
    return 
}
print ("/(PERSON1: \(woman))")



class A {
    
    init(person: Person?) {
        self.person = person
    }
    
    let person: Person?
    
    
    
    
    
}
