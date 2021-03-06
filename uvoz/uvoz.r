# 2. faza: Uvoz podatkov
library(readr)
library(dplyr)
library(tidyr)
library(rvest)
library(gsubfn)

#sl <- locale("sl", decimal_mark=",", grouping_mark=".")

# Funkcija, ki uvozi občine iz Wikipedije
uvozi.obcine <- function() {
  link <- "http://sl.wikipedia.org/wiki/Seznam_ob%C4%8Din_v_Sloveniji"
  stran <- html_session(link) %>% read_html()
  tabela <- stran %>% html_nodes(xpath="//table[@class='wikitable sortable']") %>%
    .[[1]] %>% html_table(dec=",")
  for (i in 1:ncol(tabela)) {
    if (is.character(tabela[[i]])) {
      Encoding(tabela[[i]]) <- "UTF-8"
    }
  }
  colnames(tabela) <- c("obcina", "povrsina", "prebivalci", "gostota", "naselja",
                        "ustanovitev", "pokrajina", "regija", "odcepitev")
  tabela$obcina <- gsub("Slovenskih", "Slov.", tabela$obcina)
  tabela$obcina[tabela$obcina == "Kanal ob Soči"] <- "Kanal"
  tabela$obcina[tabela$obcina == "Loški potok"] <- "Loški Potok"
  for (col in c("povrsina", "prebivalci", "gostota", "naselja", "ustanovitev")) {
    if (is.character(tabela[[col]])) {
      tabela[[col]] <- parse_number(tabela[[col]], na="-", locale=sl)
    }
  }
  for (col in c("obcina", "pokrajina", "regija")) {
    tabela[[col]] <- factor(tabela[[col]])
  }
  return(tabela)
}

# 1. tabela  
prevedba6 <- c('Prihod letal' = 'uvoz', 
               'Odhod letal' = 'izvoz')
  
letalski_potniski_in_blagovni_promet <- read_csv2("podatki/letalski_potniški_in_blagovni_promet.csv", skip=4,
                    locale=locale(encoding="CP1250"),  col_names = c('MESEC', 'tovor', 'prevoz', 'drzave', 'tone', 'potniki')) %>%
  separate(MESEC, sep="M", c("leto", "mesec")) %>%
  mutate(leto=parse_number(leto), mesec=parse_number(mesec)) 

letalski_potniski_in_blagovni_promet <- letalski_potniski_in_blagovni_promet[,-c(4,5)] %>% 
  mutate(tovor = prevedba6[tovor]) %>% 
  group_by(tovor, leto) %>% summarise(tone = sum(tone), potniki = sum(potniki)) 

letalski_potniski_promet <- letalski_potniski_in_blagovni_promet[, -c(3)] %>%
  arrange(leto) 
letalski_potniski_promet$potniki <- letalski_potniski_promet$potniki / 1000

letalski_blagovni_promet <- letalski_potniski_in_blagovni_promet[, -c(4)] %>% 
  arrange(leto)
letalski_blagovni_promet$tone <- letalski_blagovni_promet$tone /1000
 

  
# 2. tabela 

prevedba <- c("Mednarodni prevoz - blago naloženo v Sloveniji"="izvoz",
              "Mednarodni prevoz - blago razloženo v Sloveniji"="uvoz")
prevedba2 <- c('Mednarodni prevoz - potniki vstopili v Sloveniji' = 'uvoz',
              'Mednarodni prevoz - potniki izstopili v Sloveniji' = 'izvoz'	)

zelezniski_potniski_promet <- read_csv2("podatki/zelezniski_potniski_promet.csv", skip = 1, locale=locale(encoding="CP1250")) 

zelezniski_potniski_promet <- zelezniski_potniski_promet[,-c(4)] %>%
  rename("tovor" = "NOTRANJI/MEDNARODNI PREVOZ") %>%
  transmute(tovor=prevedba2[tovor],
            leto = LETO,
            potniki = `Potniki (1000)`)

zelezniski_blagovni_promet <- read_csv2('podatki/zelezniski_blagovni_promet.csv', skip= 1,locale=locale(encoding="CP1250")) %>%
  rename("TRANSPORT" = "NOTRANJI / MEDNARODNI PREVOZ") %>%
  transmute(tovor=prevedba[TRANSPORT],
         leto = LETO,
         tone = `Tone (1000)`)




# 3. tabela 

prevedba5 <- c('Mednarodni prevoz - blago naloženo v Sloveniji' = 'izvoz',
               'Mednarodni prevoz - blago razloženo v Sloveniji' = 'uvoz')

cestni_blagovni_promet <- read_csv2('podatki/cestni_blagovni_promet.csv', skip=2,locale=locale(encoding="CP1250"))
cestni_blagovni_promet <- cestni_blagovni_promet[,-c(4, 5)] %>% 
  transmute(tovor = prevedba5[`NOTRANJI / MEDNARODNI PREVOZ`],
            leto = LETO,
            tone = `Tone (1000)`)

# 4. tabela

prevedba3 <- c('Odpotovali potniki' = 'izvoz', 'Prispeli potniki' = 'uvoz')
prevedba4 <- c('Razloženi tovor, uvoz' = 'uvoz','Naloženi tovor, izvoz' = 'izvoz')

pristaniski_potniski_promet <- read_csv2('podatki/pristaniski_potniski_promet.csv',
                                         skip = 1, locale=locale(encoding="CP1250"), na = '0') %>%
  rename(tovor=`PROMET POTNIKOV`) %>%
  gather(key="leto.mesec", value="stevilo", -tovor) %>%
  separate(leto.mesec, c("leto", "mesec"), "M") %>%
  mutate(leto=parse_number(leto), mesec=parse_number(mesec)) %>%
  group_by(leto, tovor) %>% summarise(Potniki = sum(stevilo)) %>%
  transmute(tovor = prevedba3[tovor],
            potniki = Potniki) %>%
  arrange(tovor)
pristaniski_potniski_promet$potniki <- pristaniski_potniski_promet$potniki /1000

pristaniski_blagovni_promet <- read_csv2('podatki/pristaniski_blagovni_promet.csv',
                                         skip = 3, locale = locale(encoding="CP1250"), na = '0',
                                         col_names = c("tovor", "leto", "tone")) %>%
  mutate(tovor = prevedba4[tovor]) %>%
  arrange(leto)

pristaniski_blagovni_promet$tone <- pristaniski_blagovni_promet$tone /1000

blagovni_promet <- bind_rows(pristaniski_blagovni_promet %>% mutate(tip="pristaniški"),
                         zelezniski_blagovni_promet %>% mutate(tip='železniški'),
                         letalski_blagovni_promet %>% mutate(tip='letalski'),
                         cestni_blagovni_promet %>% mutate(tip="cestni"))

blagovni_promet$tone <- blagovni_promet$tone / 1000


potniski_promet <- bind_rows(pristaniski_potniski_promet %>% mutate(tip = 'pristaniški'),
                             zelezniski_potniski_promet %>% mutate(tip = 'zeležniški'),
                         letalski_potniski_promet %>% mutate(tip= 'letalski'))

potniski_promet$potniki <- potniski_promet$potniki / 1000

# 5. tabela 
#lin <- 'file:///C:/Users/Lara/Downloads/rail_pa_total%20(1).html'
#stran <- html_session(lin) %>% read_html()
#tabela <- stran %>% html_nodes(xpath="//table[@class='wikitable sortable']") %>%
#  .[[1]] %>% html_table(dec=",")

evropski_potniski_promet <- read_csv('podatki/evropa_ljudje.csv' ,  locale=locale(encoding="CP1250"), na = ':') %>%
  select('TIME', 'GEO', 'Value') %>% 
  rename(Leto = TIME, Države = GEO, Potniki = Value )

evropski_potniski_promet$Države[evropski_potniski_promet$Države == 'Germany (until 1990 former territory of the FRG)']<- 'Germany'

evropski_blagovni_promet <- read_csv('podatki/evropa_dobrine.csv' ,  locale=locale(encoding="CP1250"), na = ':') %>% 
  select('TIME', 'GEO', 'Value') %>% 
  rename(Leto = TIME, Države = GEO, Blago = Value )

evropski_blagovni_promet$Države[evropski_blagovni_promet$Države == 'Germany (until 1990 former territory of the FRG)']<- 'Germany'

evropa_promet <- inner_join(evropski_blagovni_promet, evropski_potniski_promet)
#  rename('Germany' = 'Germany (until 1990 former territory of the FRG)'[Države])
evropa_promet <- na.omit(evropa_promet)


# Zapišimo podatke v razpredelnico obcine
#obcine <- uvozi.obcine()

# Zapišimo podatke v razpredelnico druzine.
#druzine <- uvozi.druzine(levels(obcine$obcina))

# Če bi imeli več funkcij za uvoz in nekaterih npr. še ne bi
# potrebovali v 3. fazi, bi bilo smiselno funkcije dati v svojo
# datoteko, tukaj pa bi klicali tiste, ki jih potrebujemo v
# 2. fazi. Seveda bi morali ustrezno datoteko uvoziti v prihodnjih
# fazah.
