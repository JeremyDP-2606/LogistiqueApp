/* eslint-disable */
// this is an auto generated file. This will be overwritten

export const getSubscriber = /* GraphQL */ `
  query GetSubscriber($id: ID!) {
    getSubscriber(id: $id) {
      id
      owner
      name
      address
      numabo
      secteur
      phone1
      phone2
      instructions
      longitude
      latitude
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      colis {
        nextToken
        __typename
      }
      type
      nb
      unsubscribed
      createdAt
      updatedAt
      missionSubscribersId
      __typename
    }
  }
`;
export const listSubscribers = /* GraphQL */ `
  query ListSubscribers(
    $filter: ModelSubscriberFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listSubscribers(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const subscriberOrderName = /* GraphQL */ `
  query SubscriberOrderName(
    $type: String!
    $name: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelSubscriberFilterInput
    $limit: Int
    $nextToken: String
  ) {
    subscriberOrderName(
      type: $type
      name: $name
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getMission = /* GraphQL */ `
  query GetMission($id: ID!) {
    getMission(id: $id) {
      id
      owner
      name
      subscribers {
        nextToken
        __typename
      }
      livreurID
      inscriptions {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      daysOfWeek
      generateDayBefore
      startTime
      startTimeZone
      tournee {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const listMissions = /* GraphQL */ `
  query ListMissions(
    $filter: ModelMissionFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listMissions(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getInscription = /* GraphQL */ `
  query GetInscription($id: ID!) {
    getInscription(id: $id) {
      id
      owner
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      livreurID
      createdAt
      updatedAt
      missionInscriptionsId
      __typename
    }
  }
`;
export const listInscriptions = /* GraphQL */ `
  query ListInscriptions(
    $filter: ModelInscriptionFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listInscriptions(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        livreurID
        createdAt
        updatedAt
        missionInscriptionsId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getTournee = /* GraphQL */ `
  query GetTournee($id: ID!) {
    getTournee(id: $id) {
      id
      owner
      name
      status
      colis {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      livreurID
      missionTourneeId
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      createdAt
      distance
      duree
      nbColis
      updatedAt
      __typename
    }
  }
`;
export const listTournees = /* GraphQL */ `
  query ListTournees(
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listTournees(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const byLivreurOrderDate = /* GraphQL */ `
  query ByLivreurOrderDate(
    $livreurID: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byLivreurOrderDate(
      livreurID: $livreurID
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const byMissionOrderDate = /* GraphQL */ `
  query ByMissionOrderDate(
    $missionTourneeId: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byMissionOrderDate(
      missionTourneeId: $missionTourneeId
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getColis = /* GraphQL */ `
  query GetColis($id: ID!) {
    getColis(id: $id) {
      id
      owner
      tournee {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      tourneeColisId
      subscriber {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      subscriberColisId
      createdAt
      position
      polyline
      distance
      duration
      address
      longitude
      latitude
      subscriberName
      lastStatus {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      logs {
        nextToken
        __typename
      }
      updatedAt
      colisLastStatusId
      __typename
    }
  }
`;
export const listColis = /* GraphQL */ `
  query ListColis(
    $filter: ModelColisFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listColis(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const byTourneeOrderPosition = /* GraphQL */ `
  query ByTourneeOrderPosition(
    $tourneeColisId: ID!
    $position: ModelIntKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelColisFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byTourneeOrderPosition(
      tourneeColisId: $tourneeColisId
      position: $position
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const bySubscriberOrderDate = /* GraphQL */ `
  query BySubscriberOrderDate(
    $subscriberColisId: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelColisFilterInput
    $limit: Int
    $nextToken: String
  ) {
    bySubscriberOrderDate(
      subscriberColisId: $subscriberColisId
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getColisStatus = /* GraphQL */ `
  query GetColisStatus($id: ID!) {
    getColisStatus(id: $id) {
      id
      owner
      colis {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      colisLogsId
      status
      message
      createdAt
      longitude
      latitude
      updatedAt
      __typename
    }
  }
`;
export const listColisStatuses = /* GraphQL */ `
  query ListColisStatuses(
    $filter: ModelColisStatusFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listColisStatuses(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const byColisOrderDate = /* GraphQL */ `
  query ByColisOrderDate(
    $colisLogsId: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelColisStatusFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byColisOrderDate(
      colisLogsId: $colisLogsId
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
export const getLocation = /* GraphQL */ `
  query GetLocation($id: ID!) {
    getLocation(id: $id) {
      id
      owner
      userId
      userName
      tourneeId
      latitude
      longitude
      lastUpdate
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const listLocations = /* GraphQL */ `
  query ListLocations(
    $filter: ModelLocationFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listLocations(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        owner
        userId
        userName
        tourneeId
        latitude
        longitude
        lastUpdate
        createdAt
        updatedAt
        __typename
      }
      nextToken
      __typename
    }
  }
`;
