/**
 * Centralized logging utility for Document Request LWC components.
 * Handles Salesforce's Proxy object wrapping and provides consistent formatting.
 *
 * Usage:
 *   import { createLogger } from 'c/docReqLogger';
 *   const logger = createLogger('MyComponent', true);
 *   logger.log('Message', data);
 */

const LOG_LEVELS = {
  DEBUG: "DEBUG",
  INFO: "INFO",
  WARN: "WARN",
  ERROR: "ERROR"
};

const STYLES = {
  DEBUG: "color: #6B7280; font-style: italic;",
  INFO: "color: #2563EB; font-weight: bold;",
  WARN: "color: #D97706; font-weight: bold;",
  ERROR: "color: #DC2626; font-weight: bold;",
  COMPONENT: "color: #7C3AED; font-weight: bold;",
  TIMESTAMP: "color: #9CA3AF; font-size: 10px;"
};

/**
 * Unwraps Salesforce Proxy objects to plain JavaScript objects.
 * This resolves the issue where console.log shows "Object" instead of data.
 * @param {*} data - Data to unwrap
 * @returns {*} - Unwrapped data
 */
function unwrapProxy(data) {
  if (data === null || data === undefined) {
    return data;
  }

  // Handle primitives
  if (typeof data !== "object") {
    return data;
  }

  // Handle arrays
  if (Array.isArray(data)) {
    return data.map((item) => unwrapProxy(item));
  }

  // Handle Error objects specially
  if (data instanceof Error) {
    return {
      name: data.name,
      message: data.message,
      stack: data.stack
    };
  }

  // Handle Salesforce Apex error format
  if (data.body && data.body.message) {
    return {
      message: data.body.message,
      errorCode: data.body.errorCode,
      statusCode: data.status,
      body: unwrapProxy(data.body)
    };
  }

  // For Proxy objects and regular objects, use JSON parse/stringify
  try {
    return JSON.parse(JSON.stringify(data));
  } catch {
    // If serialization fails, return a description
    return `[Unserializable: ${Object.prototype.toString.call(data)}]`;
  }
}

/**
 * Formats a timestamp for logging
 * @returns {string} - Formatted timestamp
 */
function getTimestamp() {
  const now = new Date();
  return now.toISOString().substr(11, 12); // HH:MM:SS.mmm
}

/**
 * Creates a logger instance for a specific component
 * @param {string} componentName - Name of the component for log prefix
 * @param {boolean} isEnabled - Whether logging is enabled
 * @returns {Object} - Logger instance with log methods
 */
export function createLogger(componentName, isEnabled = false) {
  const prefix = `[DocReq:${componentName}]`;

  /**
   * Internal log function
   */
  function logMessage(level, message, ...args) {
    if (!isEnabled && level !== LOG_LEVELS.ERROR) {
      return; // Always log errors, but skip others if disabled
    }

    const timestamp = getTimestamp();
    const unwrappedArgs = args.map((arg) => unwrapProxy(arg));

    // Console method mapping
    const consoleMethod =
      level === LOG_LEVELS.ERROR
        ? console.error
        : level === LOG_LEVELS.WARN
          ? console.warn
          : level === LOG_LEVELS.DEBUG
            ? console.debug
            : console.log;

    // Styled console output
    consoleMethod(
      `%c${timestamp} %c${prefix} %c[${level}]%c ${message}`,
      STYLES.TIMESTAMP,
      STYLES.COMPONENT,
      STYLES[level],
      "",
      ...unwrappedArgs
    );
  }

  return {
    /**
     * Check if logging is enabled
     */
    get enabled() {
      return isEnabled;
    },

    /**
     * Log debug message (only when enabled)
     */
    debug(message, ...args) {
      logMessage(LOG_LEVELS.DEBUG, message, ...args);
    },

    /**
     * Log info message (only when enabled)
     */
    log(message, ...args) {
      logMessage(LOG_LEVELS.INFO, message, ...args);
    },

    /**
     * Log info message (alias for log)
     */
    info(message, ...args) {
      logMessage(LOG_LEVELS.INFO, message, ...args);
    },

    /**
     * Log warning message (only when enabled)
     */
    warn(message, ...args) {
      logMessage(LOG_LEVELS.WARN, message, ...args);
    },

    /**
     * Log error message (ALWAYS logged, even when disabled)
     */
    error(message, ...args) {
      logMessage(LOG_LEVELS.ERROR, message, ...args);
    },

    /**
     * Log a table of data (only when enabled)
     */
    table(data, label = "Data") {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[TABLE]%c ${label}:`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        STYLES.INFO,
        ""
      );
      console.table(unwrapProxy(data));
    },

    /**
     * Log a group of related messages (only when enabled)
     */
    group(label) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.groupCollapsed(
        `%c${timestamp} %c${prefix} %c${label}`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        STYLES.INFO
      );
    },

    /**
     * End a log group
     */
    groupEnd() {
      if (!isEnabled) return;
      console.groupEnd();
    },

    /**
     * Log component state (only when enabled)
     */
    state(stateObj) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[STATE]%c Component State:`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        STYLES.DEBUG,
        ""
      );
      console.log(unwrapProxy(stateObj));
    },

    /**
     * Log an API call start (only when enabled)
     */
    apiStart(methodName, params) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[API→]%c Calling ${methodName}`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        "color: #059669; font-weight: bold;",
        "",
        unwrapProxy(params)
      );
    },

    /**
     * Log an API call success (only when enabled)
     */
    apiSuccess(methodName, result) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[API✓]%c ${methodName} succeeded`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        "color: #059669; font-weight: bold;",
        "",
        unwrapProxy(result)
      );
    },

    /**
     * Log an API call failure (ALWAYS logged)
     */
    apiError(methodName, error) {
      const timestamp = getTimestamp();
      console.error(
        `%c${timestamp} %c${prefix} %c[API✗]%c ${methodName} failed`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        "color: #DC2626; font-weight: bold;",
        "",
        unwrapProxy(error)
      );
    },

    /**
     * Log lifecycle event (only when enabled)
     */
    lifecycle(event) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[LIFECYCLE]%c ${event}`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        "color: #8B5CF6; font-weight: bold;",
        ""
      );
    },

    /**
     * Log user action (only when enabled)
     */
    action(actionName, data) {
      if (!isEnabled) return;

      const timestamp = getTimestamp();
      console.log(
        `%c${timestamp} %c${prefix} %c[ACTION]%c ${actionName}`,
        STYLES.TIMESTAMP,
        STYLES.COMPONENT,
        "color: #F59E0B; font-weight: bold;",
        "",
        data ? unwrapProxy(data) : ""
      );
    }
  };
}

/**
 * Export the unwrapProxy utility for direct use
 */
export { unwrapProxy };
