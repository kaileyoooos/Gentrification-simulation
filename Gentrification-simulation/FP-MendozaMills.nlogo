; CS 390 W25 Term Project
; Kailey Mendoza and Matthew Mills
; model simulating gentrification of a neighborhood based on

; *---Setting up with to go button and patches own, breeds, turtle owns ---*
patches-own [
  zone             ; "cbd", "semi", "periphery"
  use-type         ; "residential", "mixed", or "commercial"
  rent-price       ; rent price for the patch
  prospective-rent ; future rent price due to gentrification
  c-time           ; months until completion of construction
]

breed [ households household ]
breed [ locals local ]
breed [ corporates corporate ]

turtles-own [
  income         ; income or revenue for this agent
  notice         ; months until rent increase (0 indicates no impending rent increase)
]

households-own [      ; these variables do not impact the simulation but could be built on for further development
  rent-status
  family-type
  household-size
  ages
]

globals [
  households-p-o            ; total number of residents priced out of simulation
]


; ============================== INTERFACE PROCEDURES ==============================

; initializes the world
to setup
  clear-all
  reset-ticks
  ask patches [set use-type nobody]
  build-zones
  initialize-real-estate
  create-agents
  invest
end

; runs the simulation
to go
  update-p-rent
  update-income
  negotiate-rent
  decide-move-out
  construct
  wait .1
  update-construction
  tick
end


; -------------------------------- BUILD THE WORLD --------------------------------


; OBSERVER CONTEXT
; generates a neighborhood with residential, mixed, and commercial zones
to build-zones
  let w (max-pxcor / 3)
  let h (max-pycor / 3)
  ask patches [
    (ifelse
      near-border? w h [
        set zone "periphery"
        set pcolor 9
        set rent-price random-normal 1200 300         ; initialize starting rent
      ]
      near-border? (w * 2) (h * 2) [
        set zone "semi"
        set pcolor 7
        set rent-price random-normal 1800 400
      ] [
        set zone "cbd"
        set pcolor 5
        set rent-price random-normal 2500 500
      ])
    ]
end

; PATCH CONTEXT
; Reports TRUE if within x units of coordinate +/- mx or y units of the +/- my
to-report near-border? [ x y ]
  report (pxcor < min-pxcor + x or pxcor > max-pxcor - x) or
         (pycor < min-pycor + y or pycor > max-pycor - y)
end

; OBSERVER CONTEXT
; distributes housing units and commercial spaces across neighborhood based on zone
to initialize-real-estate
  ask n-of (housing-units * .7) patches with [zone = "periphery"] [
    set use-type "residential"
    set pcolor 38
  ]
    ask n-of (housing-units * .2) patches with [zone = "semi"] [
    set use-type "residential"
    set pcolor 38
  ]
    ask n-of (housing-units * .1) patches with [zone = "cbd"] [
    set use-type "residential"
    set pcolor 38
  ]
    ask n-of (commercial-spaces * .1) patches with [zone = "periphery"] [
    set use-type "commercial"
    set pcolor 108
  ]
    ask n-of (commercial-spaces * .2) patches with [zone = "semi"] [
    set use-type "commercial"
    set pcolor 108
  ]
    ask n-of (commercial-spaces * .7) patches with [zone = "cbd"] [
    set use-type "commercial"
    set pcolor 108
  ]

end


; *---- Agent creation of with creation of houseowners and renters ---*

; OBSERVER CONTEXT
; builds corporate businesses in empty patches
; starts creating the business into the areas of cbd or semi
; once those blue patches are completed it will start creating new blue patches to expand there
; starting with identifying commercial space then classifying available space dependent on the zone
; it counts the available space to determine the  extra space needed an then begins to add
to invest
 let available-blue patches with [
   use-type = "commercial" and
   pcolor = 108 and
   (zone = "cbd" or zone = "semi" or zone = "periphery") and
   not any? turtles-here
 ]

 let available-blue-cbd-semi available-blue with [zone != "periphery"]
 let available-blue-peripheral available-blue with [zone = "periphery"]

 let count-cbd-semi count available-blue-cbd-semi
 let count-peripheral count available-blue-peripheral
 let total-available count-cbd-semi + count-peripheral
 let extra-needed max (list 0 (num-corp-business - total-available))

 if count-cbd-semi >= num-corp-business [
   ask n-of num-corp-business available-blue-cbd-semi [ create-business ]
 ]
 if count-cbd-semi < num-corp-business and total-available >= num-corp-business [
   ask available-blue-cbd-semi [ create-business ]
   ask n-of (num-corp-business - count-cbd-semi) available-blue-peripheral [ create-business ]
 ]
 if total-available < num-corp-business [
   ask available-blue [ create-business ]
   ask n-of extra-needed patches with [
     use-type = nobody and
     (zone = "cbd" or zone = "semi" or zone = "periphery") and
     not any? turtles-here
   ] [
     set pcolor 108
     create-business
   ]
 ]
end

to create-business
 set use-type "commercial"
 set rent-price prospective-rent
 sprout-corporates 1 [
   set shape "pentagon"
   set income random-normal 20000 5000
 ]
end

; OBSERVER CONTEXT
; if the prospective rent is 50% higher than the actual rent than it will start construction of radius 2
; changes color to represent that it is reserved since taking into account construction time it will take more than 9 months
; with the construction of these luxury apartments/malls/erehwon markets the rent will be increased
to construct
  let possible-patches patches with [prospective-rent >= rent-price * 0.5 and not any? turtles-here]
  ;print (word "Potential construction sites found: " count possible-patches)

  if any? possible-patches [
    ask one-of possible-patches [
      ;print "Starting construction here" used for debugging

      let construction-area patches in-radius 2 with [
        not any? turtles-here and (use-type = nobody or use-type = "vacant")
      ]
      ;print (word "Number of patches reserved for construction: " count construction-area); used for debugging

      if count construction-area >= 5  [
        ask construction-area [
          set pcolor 115
          set use-type "construction"
          set c-time 9
        ]
      ]
    ]
  ]
end


; OBSERVER CONTEXT
; more to add change color based on income?
; do we want to section off people in our town to show redlinning
; create households and small businesses in the neighborhood
; UPDATE WITH CENCUS
to create-agents

  ; creates and distributes households across zones according to bid-rent model
  create-households renters [
    set shape "person"
    set rent-status "renter"
    initialize-household
    move-to one-of patches with [not any? turtles-here and use-type = "residential"]
  ]

  ; initializes local businesses
  create-locals num-locals [
    ;set agent-type "small-business"
    set shape "house"
    set income random-normal 10000 2000
    move-to one-of patches with [not any? turtles-here and use-type = "commercial"]
  ]
end

; OBSERVER CONTEXT
; initialize household attributes based on census data
; could potentially set family-type to also include individuals who live alone
to initialize-household
  set family-type "family"
  let sizeage draw-household-size
  set household-size sizeage
  set ages generate-ages sizeage
  set income draw-income
  ;move-to one-of patches with [ use-type = "residential" ]
end

; *--- initialization reporters ---*

; generates and returns a household size based on probability
; generating floating random and uses ifelse to determine how many people live in the house
; the percetages come from the 2009 cencus percentages of people in each house hold
to-report draw-household-size
  let r random-float 1
  report ifelse-value (r < 0.241) [1] [      ;24.1%
    ifelse-value (r < 0.546) [2] [           ;30.5%
      ifelse-value (r < 0.713) [3] [         ;16.7%
        ifelse-value (r < 0.864) [4] [       ;15.1%
          ifelse-value (r < 0.942) [5] [     ;7.8%
            ifelse-value (r < 0.975) [6] [7] ;3.3 %
          ]
        ]
      ]
    ]
  ]
end

; taking into account those created from the draw household-size we it creates an empty list for the ages
; with each individual getting an age from the US cencus with 30% being a child 60% adults and 10% senior
; should report back a list of ages for each family household
to-report generate-ages [sizeage]
  let agesfam []
  repeat sizeage [
    let age-group ifelse-value (random-float 1 < 0.3) ["child"] [
      ifelse-value (random-float 1 < 0.6) ["adult"] ["senior"]
    ]
    set agesfam lput (random-age age-group) agesfam
  ]
  report agesfam
end


; generate a random age for a given age group
to-report random-age [group]
  if group = "child" [ report random 18 ]
  if group = "adult" [ report 18 + random 47 ] ; 18-64
  if group = "senior" [ report 65 + random 35 ] ; 65-99
end

; draw income based on distribution from probability with income and probability of obtaining it right next to it
to-report draw-income
  let r random-float 1
  let brackets [[69016 4.4] [80612 3.0] [100000 2.4] [74037 2.8] [67017 2.8] [86417 2.7]
                [76450 2.8] [978929 2.8] [52362 5.4] [58686 7.9] [30830 11.8]
                [47285 10.1] [45407 7.8] [40185 11.1] [50879 19.4]]
  let cumulative-sum 0
  foreach brackets [bracket ->  ; Define bracket as the current list item
    let countincome item 0 bracket  ; Get the income value
    let percent item 1 bracket  ; Get the probability percentage
    set cumulative-sum cumulative-sum + percent
    if (r * 100) < cumulative-sum [
      report random-normal countincome (countincome * 0.1)  ; Generate income within range
    ]
  ]
  report 40000  ; Default income if no bracket is found
end


; ----------------------------- AGENT AND RENT PROCEDURES -----------------------------

; OBSERVER CONTEXT
; counts down construction time
to update-construction
  ask patches with [use-type = "construction" and c-time > 0] [
    set c-time c-time - 1
  ]
  ask patches with [use-type = "construction" and c-time = 0] [
    set use-type "residential"
    set pcolor 117
    set rent-price prospective-rent * 1.5
  ]
end


; OBSERVER CONTEXT
; asks patches to set new prospective rent based on nearby
; amenities and surrounding rent prices
to update-p-rent
  ask patches [
    set prospective-rent (prospective-rent + 100 * count corporates in-radius 4)    ; increases prospective rent each month soley based on number of nearby corporate businesses, compounds over time
    (ifelse
      use-type = "residential" [
        (ifelse
          residential-vacancy > .10 [ set prospective-rent prospective-rent * 0.99]
          residential-vacancy < .5 [ set prospective-rent prospective-rent * 1.005 ])
      ]
      use-type = "commercial" [
        (ifelse
          commercial-vacancy > .15 [ set prospective-rent prospective-rent * 0.99]
          commercial-vacancy < .1 [ set prospective-rent prospective-rent * 1.005 ])])
  ]
  repeat 3 [ diffuse prospective-rent 0.05 ]
end

; OBSERVER CONTEXT
; asks households and businesses to renegotiate their rent
; prices based on updated prospective rent
to negotiate-rent                                 ; user can determine requirement for rent increase notice; provides a random outcome for rent increase negotiations
  ask turtles [                                ; this aspect of the model is slightly inaccurate, negotiates based on current p-rent, not when the notice was given
    (ifelse
      notice = 0 [ if prospective-rent > rent-price + 200 [ set notice 1 set color 17 ] ]   ; if prospective rent is over 200 below market rate, assign notice of rent increase
      months-notice = notice [ set rent-price prospective-rent * (0.6 + random-float 0.4) set notice 0 set color 0 ]  ; once notice is up, adjusts rent
      [ set notice notice + 1 ])
  ]
end

; OBSERVER CONTEXT
; updates income of all households, locals, and corporates
to update-income
  ask households [ set income income * 1.0025 ]       ; annual income increases 3% per year
  ask locals [ set income income + 100 * count (households in-radius 5) ]  ; increases revenue based on number of nearby households
  ask corporates [ set income income + 100 * count (households in-radius 5) ]
end

; HOUSEHOLD/SMALL-BUSINESS CONTEXT
; we want them to move out to another part of the town or just die?
; currently at move out if rent is more than 30% of their income
; for business they move out if it is more than 50% we can always change these ratios on more data
; Decide whether to move out if rent exceeds income capacity
to decide-move-out
  ask households [
    if [rent-price] of patch-here * 12 > (income * 0.4) [
        ifelse find-space = nobody [ set households-p-o households-p-o + 1 die ]
        [ move-to find-space ]
    ]
  ]
  ask corporates [ ; MAKE LOCAL/CORPORATE A FEATURE OF ALL BUSINESSES
    if [rent-price] of patch-here * 12 > (income * 0.7) [
        ifelse find-space = nobody [ set households-p-o households-p-o + 1 die ]
        [ move-to find-space ]
    ]
  ]
  ask locals [
    if [rent-price] of patch-here * 12 > (income * 0.7) [
        ifelse find-space = nobody [ set households-p-o households-p-o + 1 die ]
        [ move-to find-space ]
    ]
  ]
end

; TURTLE CONTEXT
; reports available patch with use type in appropriate rent range or nobody if none are available
to-report find-space
  let u nobody
  ifelse is-household? self [ set u "residential" ] [ set u "commercial" ]
  report one-of patches with [ not any? turtles-here and use-type = u and rent-price <= [income] of myself * 0.4 ]
end

; ------------------------- PLOT AND VISUALIZATION REPORTERS -------------------------

; reports the total number of houeseholds who have left the nieghborhood due to rising rent
to-report priced-out
  report households-p-o
end

; reports the rate of "residential" patches with no tenants (no household)
to-report residential-vacancy
  report (count patches with [use-type = "residential"] - count households) / (count patches with [use-type = "residential"])
end

; reports the rate of "commercial" patches with no tenants (no local or corporate)
to-report commercial-vacancy
  report (count patches with [use-type = "commercial"] - (count locals + count corporates)) / (count patches with [use-type = "commercial"])
end

; reports mean rent-price of all patches
to-report average-rent
  let s 0
  let c 0
  ask patches with [not (rent-price = nobody)] [
    set s s + [rent-price] of self
    set c c + 1
  ]
  report s / c
end
@#$#@#$#@
GRAPHICS-WINDOW
258
21
1059
563
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-30
30
-20
20
0
0
1
ticks
30.0

BUTTON
109
63
181
96
Go / Ir
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
144
199
177
num-corp-business
num-corp-business
1
100
81.0
1
1
NIL
HORIZONTAL

BUTTON
20
193
199
226
invest/ clic para invertir
invest
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
27
104
173
142
número de negocios corporativos 
13
0.0
0

SLIDER
18
250
190
283
num-locals
num-locals
0
50
33.0
1
1
NIL
HORIZONTAL

SLIDER
18
295
190
328
renters
renters
50
200
200.0
10
1
NIL
HORIZONTAL

BUTTON
26
63
92
96
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
338
188
371
months-notice
months-notice
1
12
4.0
1
1
NIL
HORIZONTAL

MONITOR
19
389
99
434
NIL
priced-out
17
1
11

SLIDER
1094
22
1266
55
housing-units
housing-units
50
250
240.0
10
1
NIL
HORIZONTAL

SLIDER
1093
72
1267
105
commercial-spaces
commercial-spaces
50
200
100.0
10
1
NIL
HORIZONTAL

MONITOR
1094
121
1188
166
NIL
average-rent
17
1
11

MONITOR
1097
188
1231
233
NIL
residential-vacancy
17
1
11

MONITOR
1096
257
1237
302
NIL
commercial-vacancy
17
1
11

TEXTBOX
9
31
159
49
configuractión\n
13
0.0
1

@#$#@#$#@
## Honor Code: taken from our responsible computing section 

“We neither gave nor received unauthorized aid on this assignment” -  MM KM

## WHAT IS IT?

This model is intended to simulate the gentrification of a neighborhood to help users understand the impact of corporate-owned businesses on neighborhood composition. 

## HOW IT WORKS

Using our household agents we were able to give the family households a sense of individuality using probabilities taken from the 2009 American Community Survey (ACS) in the state of California. We created household agents with household sizes and lists of the ages of people living together. They have an income status while the corporate and local business have an income and rent status. Taking into account these factors families will move out if their rent is 30% of their income while local businesses move out if their rent is more than 50% of their income. While these agents are working when the prospective rent price is 50% higher than the actual rent price we are able to see the increase of investors constructing in the world noted by the different patches of purple.

## HOW TO USE

Press setup to generate a randomized neighborhood.

Press go to run the simulation.

Adjust Sliders:
*num-corp-businesses* - number of corporate-owned businesses initialized in the world. INVEST button adds additional businesses according to the slider value.
*num-locals* - the number locally-owned businesses initialized in the world
*renters* - the number of households living in the world.
*months-notice* - the required notice period for rent increase
*housing-units* - the number of housing units initialized in the world
*commercial-spaces* - the number of commercial spaces initialized in the world

## Overview

World: a niehgborhood with a central business district, mixed use zone, and residential periphery

Land-use: simplified to residential, commercial, and undevelopped (no infrastructure or  amenities)

Households: only income factors into running of the simulation

Businesses: simplified to corporate owned and locally owned. Only corporate owned businesses significantly drive up rents. No specification in business type or competition.

Process Overview & Scheduling:
1. Property owners (observer/patch context) decide to rent (update-rent), decide whether or not to raise the rent, both prospective and actual rent
2. Households receive income and decide whether or not they can stay
3. Businesses generate (calculate) revenue and decide whether or not to stay
4. Vacant spaces are filled
5. New construction begins
6. In-progress construction continues/finishes


## THINGS TO NOTICE

Notice how residential prices in the central business distric increase faster. Note how different sliders affect vacancy rates and the number of people priced out of the nieghborhood.

## Improvements since presenting: 

In the households if you scroll down on the inspection a list of ages now appears for every person in the household. The probability of ages was generated from 2009 cencus data. It is mainly there to display that all the households are different. - KM

The construction function is now working! It colors the patches that are available to invest in a dark purple, it waits 9 months and then the construction is there noted by the light purple color, because the procedure is connected to the go button i put a wait so that it won't process the command insanely fast. To ensure that it was waiting the right months I pause and inspected the patches.- KM 

## EXTENDING THE MODEL

If we were to further extend the model we would include the following : 
Demand pressure, vertical development, rental contracts, property ownership, demographics (family structure, age, race), amenities (parks, school, transportation), multiple neighborhoods, importation of GIS data, and anti-gentrification measures. And, many more the list can continue forever : D! 

## Responsible Computing 

Do we want to add it here or submit it through email? 


## CREDITS AND REFERENCES

ACS 2009 (5-Year Estimates) 

Los Angeles - Gentrification and Displacement 
https://www.urbandisplacement.org/maps/los-angeles-gentrification-and-displacement/

A Proximity-Based Early Warning System for Gentrification in California Askash Pattabi 
https://cs229.stanford.edu/proj2018/report/71.pdf
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
