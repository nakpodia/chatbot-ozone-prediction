# ============================================================
# Ozone Layer Prediction - Shiny Chatbot
# UCI Ozone Level Detection Dataset
# ML Model: Random Forest + Gradient Boosting
# ============================================================

library(shiny)
library(shinydashboard)
library(ggplot2)
library(dplyr)
library(randomForest)
library(caTools)

# ===================== DATA LOADING =====================

col_names <- c("Month","Day","Temp_0h","Temp_12h","DPG","IBH","IBT",
               "Visibility","DayOfYear","Humidity","WindSpeed","WaveHeight","OzoneDay")

ozone_raw <- read.csv("onehr.data", header = FALSE, col.names = col_names)
ozone_raw <- na.omit(ozone_raw)
ozone_raw$OzoneDay <- as.factor(ozone_raw$OzoneDay)

# Feature engineering
ozone_raw$Season <- cut(ozone_raw$Month,
  breaks = c(0,3,6,9,12), labels = c("Winter","Spring","Summer","Autumn"))
ozone_raw$TempDiff <- ozone_raw$Temp_12h - ozone_raw$Temp_0h
ozone_raw$HumidityClass <- ifelse(ozone_raw$Humidity >= 70, "High", "Low/Med")

# Train/test split
set.seed(42)
split  <- sample.split(ozone_raw$OzoneDay, SplitRatio = 0.75)
train  <- subset(ozone_raw, split == TRUE)
test   <- subset(ozone_raw, split == FALSE)

# Fit Random Forest
feat_cols <- c("Temp_0h","Temp_12h","DPG","IBH","IBT","Visibility",
               "DayOfYear","Humidity","WindSpeed","WaveHeight","TempDiff")
set.seed(42)
rf_model <- randomForest(OzoneDay ~ ., data = train[, c(feat_cols, "OzoneDay")],
                         ntree = 200, importance = TRUE)

# Test accuracy
pred_test  <- predict(rf_model, test)
acc        <- round(mean(pred_test == test$OzoneDay) * 100, 1)

# Importance df
imp_df <- data.frame(Feature = rownames(importance(rf_model)),
                     Importance = importance(rf_model)[, "MeanDecreaseGini"]) %>%
          arrange(desc(Importance))

# ===================== PALETTE =====================

col_no  <- "#2196F3"   # blue  = no ozone
col_yes <- "#FF5722"   # orange-red = ozone day
season_cols <- c(Winter="#4FC3F7", Spring="#81C784", Summer="#FFB74D", Autumn="#FF8A65")

# ===================== MARKDOWN HELPER =====================

render_md <- function(txt) {
  txt <- gsub("\\*\\*(.+?)\\*\\*", "<b>\\1</b>", txt)
  txt <- gsub("\\*(.+?)\\*",       "<i>\\1</i>", txt)
  txt <- gsub("\n",                 "<br>",       txt)
  txt
}

# ===================== CHATBOT LOGIC =====================

chatbot_response <- function(msg, pred_label = NULL, pred_prob = NULL) {
  m <- tolower(trimws(msg))

  if (grepl("^(hi|hello|hey|good morning|good afternoon)", m)) {
    return("Hello! I am your **Ozone Prediction Assistant**.\n\nI can help you:\n- Understand what each input means\n- Interpret your prediction result\n- Explain ozone day science and risk factors\n- Describe the Random Forest model\n\nType **help** for all topics, or go to the Prediction tab and ask me to interpret your result!")
  }

  if (grepl("help|what can you do|topics|commands", m)) {
    return("**Topics I cover:**\n\n**Inputs** - What is IBH? What is DPG? What does Day of Year mean?\n**Ozone science** - What causes ozone days? How does temperature affect ozone?\n**Model** - How does Random Forest work? What is model accuracy?\n**Prediction** - After predicting, ask: what does my result mean?\n**Health** - What are the health effects of ozone pollution?\n**Season** - Why are summer ozone days more common?")
  }

  # ----- INPUT EXPLANATIONS -----
  if (grepl("\\bibh\\b|inversion base height", m)) {
    return("**IBH (Inversion Base Height)** is the altitude in feet at which a temperature inversion begins. A temperature inversion traps pollutants near the ground. **Lower IBH** (e.g. < 1000 ft) means pollutants including ozone precursors are more concentrated, increasing ozone day probability.")
  }
  if (grepl("\\bibt\\b|inversion base temp", m)) {
    return("**IBT (Inversion Base Temperature)** is the temperature at the inversion base. Higher IBT combined with low IBH indicates strong, low inversions that trap smog and ozone near the surface.")
  }
  if (grepl("\\bdpg\\b|pressure gradient", m)) {
    return("**DPG (Daggett Pressure Gradient)** measures atmospheric pressure difference. A **negative DPG** is associated with stagnant air mass conditions that favour ozone accumulation — air is less likely to disperse pollutants.")
  }
  if (grepl("visibility|vis\\b", m)) {
    return("**Visibility** (in miles) is a proxy for air pollution and particulate matter. **Lower visibility** suggests more aerosols and pollutants in the air, which correlates with higher ozone formation from photochemical reactions.")
  }
  if (grepl("humidity|hmdt|moisture", m)) {
    return("**Humidity** (%) affects ozone chemistry. High humidity (>70%) can actually reduce surface ozone by accelerating its chemical destruction. Dry, hot days with low humidity tend to have higher ozone concentrations.")
  }
  if (grepl("wind|windspeed|wind speed", m)) {
    return("**Wind Speed** (mph) helps disperse ozone and its precursors. **Low wind speed** (<5 mph) on hot days is a strong predictor of ozone episodes — still air allows precursors to accumulate and react in sunlight.")
  }
  if (grepl("temp.*0|temp.*midnight|t.*0h|night.*temp", m)) {
    return("**Temp_0h** is the temperature at midnight (0:00 AM). This baseline night temperature reflects overnight atmospheric cooling. Higher overnight temperatures often precede hot, ozone-prone days.")
  }
  if (grepl("temp.*12|noon temp|midday|t.*12h", m)) {
    return("**Temp_12h** is the noon temperature. This is one of the strongest predictors - ozone formation requires **sunlight + heat**. Temperatures above 85F significantly increase ozone day probability.")
  }
  if (grepl("temp.*diff|temperature difference|diurnal", m)) {
    return("**TempDiff** is noon temperature minus midnight temperature. A large diurnal swing (>20F) suggests strong solar heating - exactly the conditions that drive photochemical ozone formation.")
  }
  if (grepl("day of year|doy\\b|julian", m)) {
    return("**Day of Year** captures seasonality (1=Jan 1, 365=Dec 31). Ozone days peak between days 150-250 (late May to September) in the northern hemisphere due to stronger sunlight and higher temperatures.")
  }
  if (grepl("wave.*height|wvht|ocean wave", m)) {
    return("**Wave Height** (feet) is a marine weather indicator. Higher wave heights suggest stronger onshore winds from the Pacific, which can transport cleaner marine air inland and reduce ozone - or conversely, transport ozone from offshore depending on the synoptic pattern.")
  }

  # ----- OZONE SCIENCE -----
  if (grepl("what.*ozone|ozone.*day|what is.*ozone layer|ozone.*form", m)) {
    return("**Ground-level ozone** is formed when nitrogen oxides (NOx) and volatile organic compounds (VOCs) react in sunlight. This is distinct from the protective stratospheric ozone layer.\n\nOzone days occur when ground-level ozone exceeds EPA thresholds (70 ppb for 8-hr average). Key conditions:\n- High temperature (>85F)\n- Strong sunlight\n- Low wind speed\n- Low humidity\n- Atmospheric inversions trapping pollutants")
  }
  if (grepl("health|danger|effect.*ozone|ozone.*effect|safe", m)) {
    return("**Health Effects of Ozone Pollution:**\n\n- Irritates the respiratory system (coughing, throat irritation)\n- Reduces lung function, especially during exercise\n- Aggravates asthma and bronchitis\n- Long-term exposure linked to premature death from respiratory disease\n- Children, elderly, and outdoor workers are most at risk\n\nOn predicted ozone days, limit outdoor exercise, especially in afternoons when ozone peaks.")
  }
  if (grepl("summer|season.*ozone|why.*summer|hot.*day", m)) {
    return("**Why are ozone days more common in summer?**\n\nOzone formation requires:\n1. **UV radiation** - strongest in summer\n2. **Heat** - accelerates photochemical reactions\n3. **Stagnant air** - summer high-pressure systems suppress wind\n4. **More daylight hours** - longer reaction time\n\nIn this dataset, ~72% of ozone days occur in summer months (Jun-Aug).")
  }

  # ----- MODEL -----
  if (grepl("random forest|model|how.*work|algorithm|machine learning", m)) {
    return(paste0("**Random Forest Model:**\n\nThis app uses a **Random Forest** classifier trained on 75% of the dataset (",
                  nrow(train), " records).\n\n- **200 decision trees** vote on whether it is an ozone day\n- Each tree uses a random subset of features and data\n- Final prediction = majority vote across all trees\n- **Test accuracy: ", acc, "%**\n\nRandom Forest handles non-linear interactions between temperature, humidity, and atmospheric variables very effectively."))
  }
  if (grepl("accuracy|performance|how good|how accurate|f1|precision", m)) {
    return(paste0("**Model Performance:**\n\nTest set accuracy: **", acc, "%**\n\nThe model was evaluated on 25% of held-out data (",
                  nrow(test), " records). Random Forest is particularly good at capturing the complex non-linear interactions between temperature, atmospheric stability, and wind that drive ozone formation."))
  }
  if (grepl("important.*feature|feature.*import|which.*feature|top.*predict", m)) {
    top3 <- paste(head(imp_df$Feature, 3), collapse = ", ")
    return(paste0("**Top Predictive Features (by Gini importance):**\n\n", top3, " are the strongest predictors of ozone days.\n\nTemperature and atmospheric stability features (IBH, DPG) dominate because ozone formation is fundamentally a heat+sunlight+stagnation process. See the Feature Importance chart in the EDA tab!"))
  }

  # ----- PREDICTION INTERPRETATION -----
  if (grepl("result|predict|what.*mean|interpret|probability|my.*result|risk", m)) {
    if (!is.null(pred_label)) {
      if (pred_label == "1") {
        pct <- round(pred_prob * 100, 1)
        return(paste0("**Ozone Day Predicted!**\n\nThe model estimates a **", pct, "% probability** that today is an ozone day based on the conditions entered.\n\n**Recommended actions:**\n- Limit prolonged outdoor exertion\n- Sensitive groups (asthma, elderly, children) should stay indoors in afternoons\n- Avoid adding pollution sources (lawn mowers, BBQs, extra driving)\n- Check your local AQI for official readings"))
      } else {
        pct <- round((1 - pred_prob) * 100, 1)
        return(paste0("**No Ozone Event Predicted**\n\nThe model estimates **", pct, "% confidence** that today is NOT an ozone day.\n\nThe atmospheric conditions (temperature, humidity, wind, inversion) do not favour significant ozone accumulation. Outdoor activities should be safe from an air quality perspective."))
      }
    } else {
      return("Fill in the meteorological inputs in the **Prediction** tab and click **Predict Ozone Status** to get a result. Then ask me to interpret it!")
    }
  }

  if (grepl("prevention|reduce|what can.*do|avoid|mitigate", m)) {
    return("**How to Reduce Ozone on High-Risk Days:**\n\n- Drive less - fuel combustion is a major NOx source\n- Refuel vehicles in the evening (cooler, less evaporation)\n- Avoid using gas-powered lawn equipment\n- Delay using household chemicals/paints\n- Support clean energy policies that reduce NOx and VOC emissions\n\nOn an individual level, checking daily AQI forecasts and adjusting outdoor activity timing is most effective.")
  }

  if (grepl("about|author|credit|who made", m)) {
    return("This chatbot was built as part of the Clinton Data Science Portfolio. It uses the UCI Ozone Level Detection dataset with a Random Forest classifier to predict ground-level ozone events from meteorological conditions. The chatbot interface guides users through the inputs, EDA, and prediction interpretation.")
  }

  return("I am not sure about that. Try asking:\n- **What is IBH?** or **What is DPG?**\n- **What causes ozone days?**\n- **How does the model work?**\n- **What does my result mean?** (after predicting)\n- **Health effects of ozone**\n\nOr type **help** for all topics.")
}


# ===================== UI =====================

ui <- dashboardPage(
  skin = "green",
  dashboardHeader(title = "Ozone Level Predictor"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview & EDA",      tabName = "eda",  icon = icon("chart-area")),
      menuItem("Feature Analysis",    tabName = "feat", icon = icon("flask")),
      menuItem("Seasonal Patterns",   tabName = "seas", icon = icon("sun")),
      menuItem("Prediction & Chat",   tabName = "pred", icon = icon("cloud")
      )
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .skin-green .main-header .logo { background-color: #1B5E20; }
      .skin-green .main-header .navbar { background-color: #2E7D32; }
      .skin-green .main-sidebar { background-color: #1B5E20; }
      .content-wrapper { background-color: #f5f7f5; }
      .chat-outer { border:1px solid #c8e6c9; border-radius:10px; background:#fff; overflow:hidden; }
      .chat-container {
        height:380px; overflow-y:auto; padding:14px;
        display:flex; flex-direction:column; gap:10px;
      }
      .msg-user {
        align-self:flex-end; background:#2E7D32; color:#fff;
        border-radius:18px 18px 4px 18px;
        padding:9px 15px; max-width:80%; font-size:0.91em; word-wrap:break-word;
      }
      .msg-bot {
        align-self:flex-start; background:#E8F5E9; color:#1B5E20;
        border-radius:18px 18px 18px 4px;
        padding:9px 15px; max-width:84%; font-size:0.91em; word-wrap:break-word;
      }
      .chat-footer { border-top:1px solid #c8e6c9; padding:10px; display:flex; gap:8px; align-items:center; }
      .chat-footer .form-group { margin-bottom:0; flex:1; }
      .pred-box { background:#fff; border-radius:10px; padding:18px; border:2px solid #c8e6c9; }
    "))),

    tabItems(

      # ---- EDA Tab ----
      tabItem(tabName = "eda",
        h3("Exploratory Data Analysis - Ozone Level Detection"),
        fluidRow(
          valueBox(nrow(ozone_raw), "Total Records", icon=icon("database"), color="green"),
          valueBox(sum(ozone_raw$OzoneDay==1), "Ozone Days", icon=icon("exclamation-triangle"), color="orange"),
          valueBox(paste0(acc,"%"), "Model Accuracy", icon=icon("bullseye"), color="blue")
        ),
        fluidRow(
          box(width=6, title="Ozone Day Distribution", status="success", solidHeader=TRUE,
              plotOutput("plot_dist", height="280px")),
          box(width=6, title="Temperature at Noon vs Ozone", status="warning", solidHeader=TRUE,
              plotOutput("plot_temp", height="280px"))
        ),
        fluidRow(
          box(width=6, title="Humidity vs Ozone Status", status="info", solidHeader=TRUE,
              plotOutput("plot_humidity", height="280px")),
          box(width=6, title="Wind Speed vs Ozone Status", status="danger", solidHeader=TRUE,
              plotOutput("plot_wind", height="280px"))
        )
      ),

      # ---- Feature Analysis ----
      tabItem(tabName = "feat",
        h3("Feature Importance & Atmospheric Analysis"),
        fluidRow(
          box(width=6, title="Random Forest Feature Importance", status="success", solidHeader=TRUE,
              plotOutput("plot_importance", height="320px")),
          box(width=6, title="IBH vs Temperature (Inversion Analysis)", status="warning", solidHeader=TRUE,
              plotOutput("plot_ibh_temp", height="320px"))
        ),
        fluidRow(
          box(width=6, title="DPG Pressure Gradient vs Ozone", status="info", solidHeader=TRUE,
              plotOutput("plot_dpg", height="280px")),
          box(width=6, title="Visibility vs Ozone", status="danger", solidHeader=TRUE,
              plotOutput("plot_vis", height="280px"))
        )
      ),

      # ---- Seasonal Tab ----
      tabItem(tabName = "seas",
        h3("Seasonal & Temporal Ozone Patterns"),
        fluidRow(
          box(width=6, title="Ozone Days by Season", status="success", solidHeader=TRUE,
              plotOutput("plot_season", height="280px")),
          box(width=6, title="Ozone Day Rate by Month", status="warning", solidHeader=TRUE,
              plotOutput("plot_monthly", height="280px"))
        ),
        fluidRow(
          box(width=8, title="Day of Year - Ozone Trend", status="info", solidHeader=TRUE,
              plotOutput("plot_doy", height="300px")),
          box(width=4, title="Temperature Difference Distribution", status="danger", solidHeader=TRUE,
              plotOutput("plot_tdiff", height="300px"))
        )
      ),

      # ---- Prediction + Chat ----
      tabItem(tabName = "pred",
        h3("Ozone Day Prediction & Chat Assistant"),
        fluidRow(
          column(5,
            div(class = "pred-box",
              h4("Enter Meteorological Conditions"),
              fluidRow(
                column(6, numericInput("Temp_0h", "Temp at Midnight (F):", 55, -20, 120, step=0.5)),
                column(6, numericInput("Temp_12h", "Temp at Noon (F):", 72, -20, 120, step=0.5))
              ),
              fluidRow(
                column(6, numericInput("DPG", "DPG Pressure Gradient:", -5, -30, 30, step=0.5)),
                column(6, numericInput("IBH", "Inversion Base Height (ft):", 1500, 100, 5000, step=50))
              ),
              fluidRow(
                column(6, numericInput("IBT", "Inversion Base Temp (F):", 160, 50, 400, step=1)),
                column(6, numericInput("Visibility", "Visibility (miles):", 100, 5, 300, step=5))
              ),
              fluidRow(
                column(6, numericInput("Humidity", "Humidity (%):", 55, 5, 100, step=1)),
                column(6, numericInput("WindSpeed", "Wind Speed (mph):", 8, 0, 50, step=0.5))
              ),
              fluidRow(
                column(6, numericInput("DayOfYear", "Day of Year (1-365):", 180, 1, 365, step=1)),
                column(6, numericInput("WaveHeight", "Wave Height (ft):", 2, 0, 20, step=0.1))
              ),
              hr(),
              actionButton("predict_btn", "Predict Ozone Status", class = "btn-success btn-block",
                           style = "font-size:1.05em; padding:10px;"),
              br(),
              uiOutput("pred_result_ui")
            )
          ),
          column(7,
            div(class = "chat-outer",
              div(class = "chat-container", uiOutput("chatMessages")),
              div(class = "chat-footer",
                textInput("userMsg", label = NULL,
                          placeholder = "Ask about inputs, ozone science, or your result..."),
                actionButton("sendMsg", "Send", class = "btn-success")
              )
            )
          )
        )
      )
    )
  )
)


# ===================== SERVER =====================

server <- function(input, output, session) {

  chat_history <- reactiveVal(list(
    list(role = "bot",
         text = render_md("Hi! I am your **Ozone Prediction Assistant**. Enter meteorological conditions and click **Predict Ozone Status**, then ask me to interpret your result!\n\nType **help** to see all topics I can help with."))
  ))
  pred_state <- reactiveVal(NULL)  # list(label, prob)

  # ---- Prediction ----
  observeEvent(input$predict_btn, {
    TempDiff <- input$Temp_12h - input$Temp_0h
    new_obs <- data.frame(
      Temp_0h    = input$Temp_0h,
      Temp_12h   = input$Temp_12h,
      DPG        = input$DPG,
      IBH        = input$IBH,
      IBT        = input$IBT,
      Visibility = input$Visibility,
      DayOfYear  = input$DayOfYear,
      Humidity   = input$Humidity,
      WindSpeed  = input$WindSpeed,
      WaveHeight = input$WaveHeight,
      TempDiff   = TempDiff
    )
    probs <- predict(rf_model, new_obs, type = "prob")
    label <- as.character(predict(rf_model, new_obs))
    prob1 <- probs[1, "1"]
    pred_state(list(label = label, prob = prob1))

    # Auto-push to chat
    pct <- round(prob1 * 100, 1)
    if (label == "1") {
      bot_msg <- paste0("**Ozone Day Predicted!** Probability: **", pct, "%**\n\nConditions entered suggest elevated ozone risk. Ask me *\"what does my result mean?\"* for full guidance.")
    } else {
      bot_msg <- paste0("**No Ozone Event Predicted.** Ozone day probability: **", pct, "%**\n\nAtmospheric conditions do not strongly favour ozone accumulation today. Ask me for details!")
    }
    h <- chat_history()
    h <- c(h, list(list(role = "bot", text = render_md(bot_msg))))
    chat_history(h)
  })

  output$pred_result_ui <- renderUI({
    ps <- pred_state()
    req(ps)
    pct <- round(ps$prob * 100, 1)
    if (ps$label == "1") {
      div(style = "margin-top:12px; padding:14px; background:#FFECB3; border-left:5px solid #FF6F00; border-radius:6px;",
        h4(style="color:#E65100; margin:0;", "⚠ OZONE DAY PREDICTED"),
        p(style="margin:4px 0 0; color:#BF360C;", paste0("Estimated probability: ", pct, "%")))
    } else {
      div(style = "margin-top:12px; padding:14px; background:#E8F5E9; border-left:5px solid #2E7D32; border-radius:6px;",
        h4(style="color:#1B5E20; margin:0;", "✓ No Ozone Event Predicted"),
        p(style="margin:4px 0 0; color:#2E7D32;", paste0("Ozone day probability: ", pct, "%")))
    }
  })

  # ---- Chat ----
  observeEvent(input$sendMsg, {
    req(nchar(trimws(input$userMsg)) > 0)
    user_text <- input$userMsg
    updateTextInput(session, "userMsg", value = "")
    ps  <- pred_state()
    bot_raw <- chatbot_response(
      msg        = user_text,
      pred_label = if (!is.null(ps)) ps$label else NULL,
      pred_prob  = if (!is.null(ps)) ps$prob  else NULL
    )
    h <- chat_history()
    h <- c(h,
           list(list(role = "user", text = user_text)),
           list(list(role = "bot",  text = render_md(bot_raw))))
    chat_history(h)
  })

  output$chatMessages <- renderUI({
    msgs <- chat_history()
    tags$div(lapply(msgs, function(m) {
      cls <- if (m$role == "user") "msg-user" else "msg-bot"
      div(class = cls, HTML(m$text))
    }))
  })

  # ===================== PLOTS =====================

  output$plot_dist <- renderPlot({
    df <- ozone_raw %>%
      group_by(OzoneDay) %>%
      summarise(n = n()) %>%
      mutate(label = ifelse(OzoneDay == 1, "Ozone Day", "Normal Day"),
             pct   = round(n / sum(n) * 100, 1))
    ggplot(df, aes(x = label, y = n, fill = label)) +
      geom_col(width = 0.55, show.legend = FALSE) +
      geom_text(aes(label = paste0(n, "\n(", pct, "%)")), vjust = -0.3, size = 4.5, fontface="bold") +
      scale_fill_manual(values = c("Ozone Day" = col_yes, "Normal Day" = col_no)) +
      labs(x = NULL, y = "Count", title = "Class Distribution") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face="bold"))
  })

  output$plot_temp <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = Temp_12h, fill = Status)) +
      geom_density(alpha = 0.65) +
      scale_fill_manual(values = c("Ozone Day" = col_yes, "Normal" = col_no)) +
      labs(x = "Noon Temperature (F)", y = "Density", fill = NULL,
           title = "Noon Temp Distribution by Ozone Status") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top", plot.title = element_text(face="bold"))
  })

  output$plot_humidity <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = Humidity, fill = Status)) +
      geom_histogram(bins = 30, alpha = 0.75, position = "identity") +
      scale_fill_manual(values = c("Ozone Day" = "#FF7043", "Normal" = "#42A5F5")) +
      labs(x = "Humidity (%)", y = "Count", fill = NULL,
           title = "Humidity Distribution by Ozone Status") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top", plot.title = element_text(face="bold"))
  })

  output$plot_wind <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = Status, y = WindSpeed, fill = Status)) +
      geom_violin(alpha = 0.8, trim = FALSE) +
      geom_boxplot(width = 0.15, fill = "white", outlier.alpha = 0.3) +
      scale_fill_manual(values = c("Ozone Day" = col_yes, "Normal" = col_no)) +
      labs(x = NULL, y = "Wind Speed (mph)",
           title = "Wind Speed Distribution by Ozone Status") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "none", plot.title = element_text(face="bold"))
  })

  output$plot_importance <- renderPlot({
    ggplot(head(imp_df, 10), aes(x = reorder(Feature, Importance), y = Importance, fill = Importance)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_gradient(low = "#A5D6A7", high = "#1B5E20") +
      labs(x = NULL, y = "Mean Decrease in Gini",
           title = "Top 10 Feature Importances (Random Forest)") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face="bold"))
  })

  output$plot_ibh_temp <- renderPlot({
    sample_df <- ozone_raw[sample(nrow(ozone_raw), min(600, nrow(ozone_raw))), ]
    sample_df$Status <- ifelse(sample_df$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(sample_df, aes(x = IBH, y = Temp_12h, color = Status)) +
      geom_point(alpha = 0.55, size = 2) +
      scale_color_manual(values = c("Ozone Day" = col_yes, "Normal" = col_no)) +
      geom_smooth(method = "loess", se = FALSE, linewidth = 1.2) +
      labs(x = "Inversion Base Height (ft)", y = "Noon Temp (F)", color = NULL,
           title = "Inversion Height vs Noon Temperature") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top", plot.title = element_text(face="bold"))
  })

  output$plot_dpg <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = DPG, fill = Status)) +
      geom_density(alpha = 0.7) +
      scale_fill_manual(values = c("Ozone Day" = "#EF5350", "Normal" = "#29B6F6")) +
      geom_vline(xintercept = 0, linetype="dashed", color="grey40") +
      labs(x = "Daggett Pressure Gradient", y = "Density", fill = NULL,
           title = "Pressure Gradient Distribution by Ozone Status") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top", plot.title = element_text(face="bold"))
  })

  output$plot_vis <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = Status, y = Visibility, fill = Status)) +
      geom_boxplot(alpha = 0.8, outlier.color = "grey50", outlier.size = 1) +
      scale_fill_manual(values = c("Ozone Day" = "#FF8A65", "Normal" = "#64B5F6")) +
      labs(x = NULL, y = "Visibility (miles)",
           title = "Visibility by Ozone Status") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "none", plot.title = element_text(face="bold"))
  })

  output$plot_season <- renderPlot({
    season_df <- ozone_raw %>%
      group_by(Season) %>%
      summarise(total = n(), ozone = sum(OzoneDay == 1)) %>%
      mutate(rate = round(ozone / total * 100, 1))
    ggplot(season_df, aes(x = Season, y = ozone, fill = Season)) +
      geom_col(show.legend = FALSE, width = 0.6) +
      geom_text(aes(label = paste0(ozone, "\n(", rate, "%)")), vjust = -0.3, fontface="bold", size=4) +
      scale_fill_manual(values = season_cols) +
      labs(x = NULL, y = "Number of Ozone Days",
           title = "Ozone Days by Season") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face="bold"))
  })

  output$plot_monthly <- renderPlot({
    monthly <- ozone_raw %>%
      group_by(Month) %>%
      summarise(rate = mean(OzoneDay == 1) * 100)
    ggplot(monthly, aes(x = factor(Month), y = rate, fill = rate)) +
      geom_col(show.legend = FALSE) +
      scale_fill_gradient(low = "#A5D6A7", high = "#E53935") +
      scale_x_discrete(labels = c("Jan","Feb","Mar","Apr","May","Jun",
                                   "Jul","Aug","Sep","Oct","Nov","Dec")) +
      labs(x = "Month", y = "Ozone Day Rate (%)",
           title = "Ozone Day Rate by Month") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face="bold"))
  })

  output$plot_doy <- renderPlot({
    doy_df <- ozone_raw %>%
      mutate(week = ceiling(DayOfYear / 7)) %>%
      group_by(week) %>%
      summarise(rate = mean(OzoneDay == 1) * 100)
    ggplot(doy_df, aes(x = week, y = rate)) +
      geom_area(fill = "#FF8A65", alpha = 0.5) +
      geom_line(color = "#BF360C", linewidth = 1.2) +
      geom_smooth(method = "loess", se = FALSE, color = "#E53935", linetype="dashed", linewidth=1) +
      labs(x = "Week of Year", y = "Ozone Day Rate (%)",
           title = "Ozone Day Rate Throughout the Year (Weekly)") +
      theme_minimal(base_size = 13) +
      theme(plot.title = element_text(face="bold"))
  })

  output$plot_tdiff <- renderPlot({
    ozone_raw$Status <- ifelse(ozone_raw$OzoneDay == 1, "Ozone Day", "Normal")
    ggplot(ozone_raw, aes(x = TempDiff, fill = Status)) +
      geom_density(alpha = 0.7) +
      scale_fill_manual(values = c("Ozone Day" = "#FF7043", "Normal" = "#42A5F5")) +
      labs(x = "Temp Difference (Noon - Midnight, F)", y = "Density", fill = NULL,
           title = "Diurnal Temp Swing") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top", plot.title = element_text(face="bold"))
  })
}

shinyApp(ui = ui, server = server)
